public class CursorWebhookJob implements Queueable, Database.AllowsCallouts {
    private static final String ENDPOINT = 'https://saleforcetocursor.c1210458037.workers.dev';
    private List<Id> recordIds;

    public CursorWebhookJob(List<Id> recordIds) {
        this.recordIds = recordIds == null ? new List<Id>() : new List<Id>(recordIds);
    }

    public void execute(QueueableContext context) {
        if (recordIds.isEmpty()) {
            return;
        }

        List<Cursor__c> updates = new List<Cursor__c>();

        for (Cursor__c record : [
            SELECT Id, Name, prompt_1__c
            FROM Cursor__c
            WHERE Id IN :recordIds
        ]) {
            Cursor__c updateRecord = new Cursor__c(Id = record.Id);

            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(ENDPOINT);
                req.setMethod('POST');
                req.setTimeout(120000);
                req.setHeader('Content-Type', 'application/json');

                Map<String, Object> payload = new Map<String, Object>{
                    'source' => 'salesforce',
                    'objectApiName' => 'Cursor__c',
                    'recordId' => record.Id,
                    'recordName' => record.Name,
                    'prompt' => record.prompt_1__c,
                    'orgId' => UserInfo.getOrganizationId(),
                    'userId' => UserInfo.getUserId(),
                    'sentAt' => System.now()
                };

                req.setBody(JSON.serialize(payload));

                HttpResponse res = new Http().send(req);
                Integer statusCode = res.getStatusCode();
                String responseBody = shorten(res.getBody(), 160);

                if (statusCode >= 200 && statusCode < 300) {
                    updateRecord.Execution_Result__c = 'Webhook sent: HTTP ' + statusCode + formatResponse(responseBody);
                } else {
                    updateRecord.Execution_Result__c = 'Webhook failed: HTTP ' + statusCode + formatResponse(responseBody);
                }
            } catch (Exception ex) {
                updateRecord.Execution_Result__c = 'Webhook error: ' + shorten(ex.getMessage(), 180);
            }

            updates.add(updateRecord);
        }

        if (!updates.isEmpty()) {
            Database.update(updates, false);
        }
    }

    private static String formatResponse(String responseBody) {
        return String.isBlank(responseBody) ? '' : ' - ' + responseBody;
    }

    private static String shorten(String value, Integer maxLength) {
        if (String.isBlank(value)) {
            return '';
        }
        return value.length() <= maxLength ? value : value.substring(0, maxLength);
    }
}