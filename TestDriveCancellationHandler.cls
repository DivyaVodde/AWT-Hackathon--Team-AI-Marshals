public with sharing class TestDriveCancellationHandler {
    
    @InvocableMethod(label='Cancel Test Drive' description='Deletes Service Appointment for cancelled test drive')
    public static List<CancelResponse> cancelTestDrive(List<CancelRequest> requests) {
        List<CancelResponse> responses = new List<CancelResponse>();
        for (CancelRequest req : requests) {
            CancelResponse resp = new CancelResponse();
            try {
                delete new ServiceAppointment(Id = req.serviceAppointmentId);
                resp.success = true;
            } catch (Exception e) {
                resp.success = false;
                resp.errorMessage = e.getMessage();
            }
            responses.add(resp);
        }
        return responses;
    }
    
    public class CancelRequest {
        @InvocableVariable
        public Id serviceAppointmentId;
    }
    
    public class CancelResponse {
        @InvocableVariable
        public Boolean success;
        @InvocableVariable
        public String errorMessage;
    }
}