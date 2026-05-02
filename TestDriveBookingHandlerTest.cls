@isTest
private class TestDriveBookingHandlerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test users first
        List<User> testUsers = new List<User>();
        testUsers.add(createTestUser('andheri@test.com'));
        testUsers.add(createTestUser('connaught@test.com'));
        testUsers.add(createTestUser('worli@test.com'));
        insert testUsers;
        
        // Query existing Territory2Type (don't create)
     /*   Territory2Type t2Type = [SELECT Id FROM Territory2Type WHERE DeveloperName = 'Dealership' LIMIT 1];
        if (t2Type == null) {
            t2Type = new Territory2Type(MasterLabel = 'Dealership', DeveloperName = 'Dealership');
            insert t2Type;
        }*/
        
        // Create Territories WITHOUT Active__c
        List<Territory2> territories = new List<Territory2>();
        territories.add(new Territory2(Name = 'Electra Neo Andheri'));
        territories.add(new Territory2(Name = 'Electra Connaught Place'));
        territories.add(new Territory2(Name = 'Electra Neo Worli'));
        insert territories;
        
        // Link users to territories
        insert new UserTerritory2Association(
            UserId = testUsers[0].Id, 
            Territory2Id = territories[0].Id, 
            RoleInTerritory2 = 'Primary Owner'
        );
        insert new UserTerritory2Association(
            UserId = testUsers[1].Id, 
            Territory2Id = territories[1].Id, 
            RoleInTerritory2 = 'Primary Owner'
        );
        insert new UserTerritory2Association(
            UserId = testUsers[2].Id, 
            Territory2Id = territories[2].Id, 
            RoleInTerritory2 = 'Primary Owner'
        );
    }
    
    @isTest
    static void testMumbaiZipAndheri() {
        TestDriveBookingHandler.BookingRequest req = 
            makeBookingRequest('Neo', '400053', 'Nafees', '9010218786', 'test@eversa.com');
        
        Test.startTest();
        List<TestDriveBookingHandler.BookingResponse> results = 
            TestDriveBookingHandler.handleBooking(new List<TestDriveBookingHandler.BookingRequest>{req});
        Test.stopTest();
        
        System.assertEquals(true, results[0].success);
        System.assertNotEquals(null, results[0].serviceAppointmentId);
        System.assertNotEquals(null, results[0].leadId);
        System.assert(results[0].assignedTerritory.contains('Electra Neo Andheri'));
    }
    
    @isTest
    static void testDelhiZip() {
        TestDriveBookingHandler.BookingRequest req = 
            makeBookingRequest('Electra', '110075', 'DelhiUser', '9999999999', 'delhi@test.com');
        
        Test.startTest();
        List<TestDriveBookingHandler.BookingResponse> results = 
            TestDriveBookingHandler.handleBooking(new List<TestDriveBookingHandler.BookingRequest>{req});
        Test.stopTest();
        
        System.assert(results[0].assignedTerritory.contains('Electra Connaught Place'));
    }
    
    @isTest
    static void testNoidaZip() {
        TestDriveBookingHandler.BookingRequest req = 
            makeBookingRequest('Neo', '201301', 'NafeesNoida', '9010218786', 'noida@test.com');
        
        Test.startTest();
        List<TestDriveBookingHandler.BookingResponse> results = 
            TestDriveBookingHandler.handleBooking(new List<TestDriveBookingHandler.BookingRequest>{req});
        Test.stopTest();
        
        System.assert(results[0].assignedTerritory.contains('Electra Connaught Place'));
    }
    
    @isTest
    static void testBulkBookings() {
        List<TestDriveBookingHandler.BookingRequest> bulkReqs = new List<TestDriveBookingHandler.BookingRequest>();
        bulkReqs.add(makeBookingRequest('Neo', '400053', 'Bulk1', null, null));
        bulkReqs.add(makeBookingRequest('Electra', '110075', 'Bulk2', null, null));
        bulkReqs.add(makeBookingRequest('Neo', '201301', 'Bulk3', null, null));
        
        Test.startTest();
        List<TestDriveBookingHandler.BookingResponse> results = 
            TestDriveBookingHandler.handleBooking(bulkReqs);
        Test.stopTest();
        
        System.assertEquals(3, results.size());
        for (TestDriveBookingHandler.BookingResponse r : results) {
            System.assertEquals(true, r.success);
        }
    }
    
    @isTest
    static void testInvalidZip() {
        TestDriveBookingHandler.BookingRequest req = 
            makeBookingRequest('Test', '99999', 'Invalid', null, null);
        
        Test.startTest();
        List<TestDriveBookingHandler.BookingResponse> results = 
            TestDriveBookingHandler.handleBooking(new List<TestDriveBookingHandler.BookingRequest>{req});
        Test.stopTest();
        
        System.assertNotEquals(null, results[0].leadId);
        System.assert(results[0].assignedTerritory.contains('Default Dealer'));
    }
    
    // ✅ Helper: Proper constructor (no name=value pairs for inner classes)
    private static TestDriveBookingHandler.BookingRequest makeBookingRequest(
        String vehicle, String zip, String name, String phone, String email) {
        TestDriveBookingHandler.BookingRequest req = new TestDriveBookingHandler.BookingRequest();
        req.vehicleModel = vehicle;
        req.zipCode = zip;
        req.customerName = name;
        req.customerPhone = phone;
        req.customerEmail = email;
        req.preferredDateTime = Datetime.now().addDays(1);
        return req;
    }
    
    private static User createTestUser(String email) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String baseAlias = email.substringBefore('@').toLowerCase();
         // ✅ TRUNCATE TO 8 CHARS MAX
    String alias = baseAlias.length() > 8 ? baseAlias.substring(0, 8) : baseAlias;
    
        return new User(
            Alias = alias,
            Email = email,
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = email.replace('@', '.') + System.currentTimeMillis() + '@test.com'
        );
    }
}