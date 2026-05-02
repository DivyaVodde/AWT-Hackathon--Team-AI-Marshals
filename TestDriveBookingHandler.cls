public with sharing class TestDriveBookingHandler {
    
    @InvocableMethod(label='Handle Test Drive Booking' 
                     description='Creates Lead → ServiceAppointment → Scans ALL City Dealerships')
    public static List<BookingResponse> handleBooking(List<BookingRequest> requests) {
        List<BookingResponse> responses = new List<BookingResponse>();
        for (BookingRequest req : requests) {
            BookingResponse resp = new BookingResponse();
            try {
                BookingResult result = createTestDriveBooking(req);
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
    
    private class BookingResult {
        public Id serviceApptId;
        public Id leadId;
        public String dealerName;
    }
    
    public class BookingRequest {
        @InvocableVariable public String vehicleModel;
        @InvocableVariable public Datetime preferredDateTime;
        @InvocableVariable public String zipCode;
        @InvocableVariable public String customerName;
        @InvocableVariable public String customerPhone;
        @InvocableVariable public String customerEmail;
    }
    
    public class BookingResponse {
        @InvocableVariable public Id serviceAppointmentId;
        @InvocableVariable public Id leadId;
        @InvocableVariable public String assignedTerritory;
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }
    
    private static BookingResult createTestDriveBooking(BookingRequest req) {
        Savepoint sp = Database.setSavepoint();
        BookingResult result = new BookingResult();
        try {
            // 1. FIND NEAREST DEALERSHIP FROM ALL CITY DEALERSHIPS
            DealerInfo dealer = findNearestDealership(req.zipCode);
            result.dealerName = dealer.dealerName;
            
            // 2. CREATE LEAD → ASSIGN DEALER OWNER
            Lead lead = new Lead(
                LastName = req.customerName,
                Company = 'Electra Test Drive - ' + req.vehicleModel,
                Phone = req.customerPhone,
                Email = req.customerEmail,
                Status = 'Qualified',
                Street = req.zipCode,
                PostalCode = req.zipCode
            );
            
            if (dealer.userId != null) {
                lead.OwnerId = dealer.userId;
            }
            insert lead;
            result.leadId = lead.Id;
            
            // 3. CREATE ServiceAppointment
            ServiceAppointment sa = new ServiceAppointment(
                ParentRecordId = lead.Id,
                Vehicle_Model__c = req.vehicleModel,
                Subject = '🚗 ' + req.vehicleModel + ' Test Drive',
                Description = 'Agentforce Booking\n' +
                             'Nearest Dealer: ' + dealer.dealerName + '\n' +
                             'Vehicle: ' + req.vehicleModel + '\nCustomer: ' + req.customerName + 
                             '\nPhone: ' + req.customerPhone + '\nZIP: ' + req.zipCode,
                SchedStartTime = req.preferredDateTime,
                SchedEndTime = req.preferredDateTime.addHours(1),
                Status = 'New',
                AppointmentType = 'Test Drive'
            );
            insert sa;
            result.serviceApptId = sa.Id;
            
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
        return result;
    }
    
    private class DealerInfo {
        public String dealerName;
        public Id territoryId;
        public Id userId;
    }
    
    // ✅ SCANS ALL DEALERSHIPS UNDER CITY TERRITORY
    private static DealerInfo findNearestDealership(String zipCode) {
        String city = getCityFromZip(zipCode);
        
        // City → All Dealership Territory IDs
        Map<String, List<String>> cityDealerships = new Map<String, List<String>>{
            'Delhi' => new List<String>{'0MIbm000000BVwX', '0MIbm000000BVuv'},  // Connaught + Dwarka
            'Noida' => new List<String>{'0MIbm000000BVwX'},                      // Connaught
            'Mumbai' => new List<String>{'0MIbm000000BSyf', '0MIbm000000BW6D', '0MIbm000000BT57'},  // Andheri + Worli + Bandra
            'Kolkata' => new List<String>{'0MIbm000000BWcT', '0MIbm000000BWe5'}, // Park Street + Salt Lake
            'Chennai' => new List<String>{'0MIbm000000BWNx', '0MIbm000000BWPZ'}  // Anna Nagar + OMR
        };
        
        List<String> dealershipTerritories = cityDealerships.get(city);
        if (dealershipTerritories == null || dealershipTerritories.isEmpty()) {
            return new DealerInfo();  // Default
        }
        
        // SCAN ALL → PICK FIRST WITH ACTIVE REP (nearest logic)
        for (String terrId : dealershipTerritories) {
            DealerInfo dealer = getDealerDetails(terrId);
            if (dealer.userId != null) {  // Has active rep
                return dealer;
            }
        }
        
        // Fallback to first dealership
        return getDealerDetails(dealershipTerritories[0]);
    }
    
    private static DealerInfo getDealerDetails(String terrId) {
        DealerInfo info = new DealerInfo();
        
        // Map Territory ID → Name (your actual names)
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
        info.dealerName = territoryNames.get(terrId);
        
        try {
            List<UserTerritory2Association> users = [
                SELECT UserId FROM UserTerritory2Association 
                WHERE Territory2Id = :terrId LIMIT 1
            ];
            if (!users.isEmpty()) {
                info.userId = users[0].UserId;
            }
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