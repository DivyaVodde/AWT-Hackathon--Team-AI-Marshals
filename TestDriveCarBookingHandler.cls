public with sharing class TestDriveCarBookingHandler {
    
    @InvocableMethod(label='Handle Test Rental Drive Booking' 
                     description='Creates Lead → ServiceAppointment → Scans ALL City Dealerships')
    public static List<BookingResponse> handleBooking(List<RequestWrapper> inputs) {
        List<BookingResponse> responses = new List<BookingResponse>();
        
        if (inputs == null || inputs.isEmpty()) {
            return responses;
        }
        
        for (RequestWrapper wrapper : inputs) {
            BookingResponse resp = new BookingResponse();
            
            if (wrapper == null || wrapper.request == null) {
                resp.success = false;
                resp.errorMessage = 'Invalid request wrapper';
                responses.add(resp);
                continue;
            }
            
            try {
                BookingResult result = createTestDriveBooking(wrapper.request);
                resp.serviceAppointmentId = result.serviceApptId;
                resp.leadId = result.leadId;
                resp.assignedTerritory = 'Assigned Nearest Dealership: ' + result.dealerName;
                resp.success = true;
            } catch (Exception e) {
                resp.success = false;
                resp.errorMessage = e.getMessage();
            }
            responses.add(resp);
        }
        return responses;
    }

    // ─────────────────────────────────────────────────────────────
    // ✅ OUTER WRAPPER — required by @InvocableMethod pattern
    // ─────────────────────────────────────────────────────────────
    public class RequestWrapper {
        @InvocableVariable(required=true)
        public BookingRequests request;
    }

    // ─────────────────────────────────────────────────────────────
    // ✅ ALL INPUT VARIABLES IN ONE WRAPPER CLASS
    //    Phone, Email, VehicleModel, ZipCode, Date + Time
    // ─────────────────────────────────────────────────────────────
    public class BookingRequests {

        @InvocableVariable(required=true  description='Customer Full Name')
        public String name;

        @InvocableVariable(required=true  description='Customer Phone Number')
        public String phone;                    // ← val.phone (LWC)

        @InvocableVariable(required=true  description='Customer Email Address')
        public String email;                    // ← val.email (LWC)

        @InvocableVariable(required=true  description='Vehicle Model for Test Drive')
        public String vehicleModel;             // ← Test Drive specific

        @InvocableVariable(required=true  description='Customer ZIP / Postal Code')
        public String zipCode;                  // ← Test Drive specific

        @InvocableVariable(required=true  description='Preferred Reservation Date (YYYY-MM-DD)')
        public Date reservationDate;            // ← val.reservationDate (LWC)

    }

    // ─────────────────────────────────────────────────────────────
    // ✅ RESPONSE WRAPPER
    // ─────────────────────────────────────────────────────────────
    public class BookingResponse {
        @InvocableVariable public Id      serviceAppointmentId;
        @InvocableVariable public Id      leadId;
        @InvocableVariable public String  assignedTerritory;
        @InvocableVariable public Boolean success;
        @InvocableVariable public String  errorMessage;
    }

    // ─────────────────────────────────────────────────────────────
    // INTERNAL RESULT HOLDER
    // ─────────────────────────────────────────────────────────────
    private class BookingResult {
        public Id     serviceApptId;
        public Id     leadId;
        public String dealerName;
    }

    // ─────────────────────────────────────────────────────────────
    // CORE BOOKING LOGIC
    // ─────────────────────────────────────────────────────────────
    private static BookingResult createTestDriveBooking(BookingRequests req) {
        Savepoint sp = Database.setSavepoint();
        BookingResult result = new BookingResult();
        try {
            // 1. FIND NEAREST DEALERSHIP
            DealerInfo dealer = findNearestDealership(req.zipCode);
            result.dealerName = dealer.dealerName;

            // 2. CREATE LEAD
            Lead lead = new Lead(
                LastName   = req.name,
                Company    = 'Electra Test Drive - ' + req.vehicleModel,
                Phone      = req.phone,          // ✅ from BookingRequests.phone
                Email      = req.email,          // ✅ from BookingRequests.email
                Status     = 'Qualified',
                Street     = req.zipCode,
                PostalCode = req.zipCode
            );
            if (dealer.userId != null) {
                lead.OwnerId = dealer.userId;
            }
            insert lead;
            result.leadId = lead.Id;

   

            // 4. CREATE ServiceAppointment
            ServiceAppointment sa = new ServiceAppointment(
                ParentRecordId   = lead.Id,
                Vehicle_Model__c = req.vehicleModel,
                Subject          = '🚗 ' + req.vehicleModel + ' Test Drive',
                Description      = 'Agentforce Booking\n'         +
                                   'Nearest Dealer: '  + dealer.dealerName + '\n' +
                                   'Vehicle: '         + req.vehicleModel  + '\n' +
                                   'Customer: '        + req.name          + '\n' +
                                   'Phone: '           + req.phone         + '\n' +
                                   'ZIP: '             + req.zipCode,
                Status           = 'New',
                AppointmentType  = 'Test Drive'
            );
            insert sa;
            result.serviceApptId = sa.Id;

        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
        return result;
    }

    // ─────────────────────────────────────────────────────────────
    // ✅ HELPER — Combines Date + "HH:mm" into Datetime
    // ─────────────────────────────────────────────────────────────
    private static Datetime buildScheduledTime(Date resDate, String startTime) {
        if (resDate != null && String.isNotBlank(startTime)) {
            List<String> parts = startTime.split(':');
            Integer hrs  = Integer.valueOf(parts[0]);
            Integer mins = parts.size() > 1 ? Integer.valueOf(parts[1]) : 0;
            return Datetime.newInstance(
                resDate.year(), resDate.month(), resDate.day(),
                hrs, mins, 0
            );
        }
        return Datetime.now().addDays(1); // safe fallback
    }

    // ── Dealership helpers (unchanged) ───────────────────────────

    private class DealerInfo {
        public String dealerName;
        public Id     territoryId;
        public Id     userId;
    }

    private static DealerInfo findNearestDealership(String zipCode) {
        String city = getCityFromZip(zipCode);
        Map<String, List<String>> cityDealerships = new Map<String, List<String>>{
            'Delhi'   => new List<String>{'0MIbm000000BVwX', '0MIbm000000BVuv'},
            'Noida'   => new List<String>{'0MIbm000000BVwX'},
            'Mumbai'  => new List<String>{'0MIbm000000BSyf', '0MIbm000000BW6D', '0MIbm000000BT57'},
            'Kolkata' => new List<String>{'0MIbm000000BWcT', '0MIbm000000BWe5'},
            'Chennai' => new List<String>{'0MIbm000000BWNx', '0MIbm000000BWPZ'}
        };
        List<String> territories = cityDealerships.get(city);
        if (territories == null || territories.isEmpty()) return new DealerInfo();
        for (String terrId : territories) {
            DealerInfo d = getDealerDetails(terrId);
            if (d.userId != null) return d;
        }
        return getDealerDetails(territories[0]);
    }

    private static DealerInfo getDealerDetails(String terrId) {
        DealerInfo info = new DealerInfo();
        Map<String, String> territoryNames = new Map<String, String>{
            '0MIbm000000BVwX' => 'Electra Connaught Place',
            '0MIbm000000BVuv' => 'Electra Dwarka',
            '0MIbm000000BSyf' => 'Electra Neo Andheri',
            '0MIbm000000BW6D' => 'Electra Neo Worli',
            '0MIbm000000BT57' => 'Electra Neo Bandra',
            '0MIbm000000BWcT' => 'Electra Park Street',
            '0MIbm000000BWe5' => 'Electra Salt Lake',
            '0MIbm000000BWNx' => 'Electra Anna Nagar',
            '0MIbm000000BWPZ' => 'Electra OMR'
        };
        info.territoryId = terrId;
        info.dealerName  = territoryNames.get(terrId);
        try {
            List<UserTerritory2Association> users = [
                SELECT UserId FROM UserTerritory2Association
                WHERE Territory2Id = :terrId LIMIT 1
            ];
            if (!users.isEmpty()) info.userId = users[0].UserId;
        } catch (Exception e) {}
        return info;
    }

    private static String getCityFromZip(String zipCode) {
        if (String.isBlank(zipCode) || zipCode.length() < 3) return null;
        String prefix = zipCode.substring(0, Math.min(6, zipCode.length())).toLowerCase();
        if (prefix.startsWith('11') || prefix.startsWith('110') || prefix.startsWith('201')) return 'Delhi';
        if (prefix.startsWith('40') || prefix.startsWith('400')) return 'Mumbai';
        if (prefix.startsWith('70') || prefix.startsWith('700')) return 'Kolkata';
        if (prefix.startsWith('60') || prefix.startsWith('600')) return 'Chennai';
        return null;
    }
}