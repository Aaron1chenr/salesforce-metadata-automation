@IsTest
private class CreateObjectApexActionTest {
    private static Integer callCount;
    private static List<String> requestBodies;
    private static List<String> endpoints;

    private class ToolingSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            endpoints.add(req.getEndpoint());
            requestBodies.add(req.getBody());

            System.assertEquals('POST', req.getMethod());
            System.assert(req.getEndpoint().contains('callout:Salesforce_Tooling/services/data/v67.0/tooling/sobjects/'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"id":"01I000000000001","success":true,"errors":[]}');
            return res;
        }
    }

    @IsTest
    static void createsCustomObjectAndFieldsFromJson() {
        callCount = 0;
        requestBodies = new List<String>();
        endpoints = new List<String>();
        Test.setMock(HttpCalloutMock.class, new ToolingSuccessMock());

        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Auto_Build__c',
            'label' => 'Auto Build',
            'pluralLabel' => 'Auto Builds',
            'description' => 'Created by invocable action test.',
            'sharingModel' => 'ReadWrite',
            'deploymentStatus' => 'Deployed',
            'nameFieldLabel' => 'Auto Build Name',
            'fields' => new List<Object>{
                new Map<String, Object>{'fieldApiName' => 'Text_Value__c', 'label' => 'Text Value', 'type' => 'Text', 'length' => 100},
                new Map<String, Object>{'fieldApiName' => 'Long_Text__c', 'label' => 'Long Text', 'type' => 'LongTextArea', 'length' => 1000, 'visibleLines' => 4},
                new Map<String, Object>{'fieldApiName' => 'Amount_Number__c', 'label' => 'Amount Number', 'type' => 'Number', 'precision' => 10, 'scale' => 2},
                new Map<String, Object>{'fieldApiName' => 'Money__c', 'label' => 'Money', 'type' => 'Currency', 'precision' => 12, 'scale' => 2},
                new Map<String, Object>{'fieldApiName' => 'Start_Date__c', 'label' => 'Start Date', 'type' => 'Date'},
                new Map<String, Object>{'fieldApiName' => 'Start_Time__c', 'label' => 'Start Time', 'type' => 'DateTime'},
                new Map<String, Object>{'fieldApiName' => 'Enabled__c', 'label' => 'Enabled', 'type' => 'Checkbox', 'defaultValue' => 'false'},
                new Map<String, Object>{'fieldApiName' => 'Status__c', 'label' => 'Status', 'type' => 'Picklist', 'picklistValues' => new List<String>{'New', 'Done'}}
            }
        });

        CreateObjectApexAction.Request actionRequest = new CreateObjectApexAction.Request();
        actionRequest.objectConfigJson = configJson;

        Test.startTest();
        List<CreateObjectApexAction.Response> responses = CreateObjectApexAction.createObjects(
            new List<CreateObjectApexAction.Request>{ actionRequest }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(true, responses[0].success, responses[0].message);
        System.assertEquals('Auto_Build__c', responses[0].objectApiName);
        System.assertEquals(9, callCount, 'One CustomObject call and eight CustomField calls are expected.');
        System.assert(requestBodies[0].contains('Auto_Build__c'));
        System.assert(String.join(requestBodies, ' ').contains('Text_Value__c'));
        System.assert(String.join(requestBodies, ' ').contains('LongTextArea'));
        System.assert(String.join(requestBodies, ' ').contains('Picklist'));
        System.assert(String.join(requestBodies, ' ').contains('valueSet'));
    }

    @IsTest
    static void rejectsInvalidObjectApiName() {
        CreateObjectApexAction.Request actionRequest = new CreateObjectApexAction.Request();
        actionRequest.objectConfigJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'InvalidObject',
            'label' => 'Invalid Object',
            'fields' => new List<Object>()
        });

        List<CreateObjectApexAction.Response> responses = CreateObjectApexAction.createObjects(
            new List<CreateObjectApexAction.Request>{ actionRequest }
        );

        System.assertEquals(1, responses.size());
        System.assertEquals(false, responses[0].success);
        System.assert(responses[0].message.contains('must end with __c'));
    }

    @IsTest
    static void rejectsInvalidFieldApiName() {
        CreateObjectApexAction.Request actionRequest = new CreateObjectApexAction.Request();
        actionRequest.objectConfigJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Valid_Object__c',
            'label' => 'Valid Object',
            'fields' => new List<Object>{
                new Map<String, Object>{'fieldApiName' => 'Bad Field__c', 'label' => 'Bad Field', 'type' => 'Text'}
            }
        });

        List<CreateObjectApexAction.Response> responses = CreateObjectApexAction.createObjects(
            new List<CreateObjectApexAction.Request>{ actionRequest }
        );

        System.assertEquals(false, responses[0].success);
        System.assert(responses[0].message.contains('can contain only letters'));
    }
}