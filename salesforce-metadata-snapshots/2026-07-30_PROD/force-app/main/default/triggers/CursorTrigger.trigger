trigger CursorTrigger on Cursor__c (after insert, after update) {
    List<Id> recordIds = new List<Id>();

    for (Cursor__c record : Trigger.new) {
        Cursor__c oldRecord = Trigger.isUpdate ? Trigger.oldMap.get(record.Id) : null;

        Boolean newlyChecked = Trigger.isInsert
            ? record.Send_To_Cursor__c == true
            : record.Send_To_Cursor__c == true && oldRecord.Send_To_Cursor__c != true;

        if (newlyChecked && String.isNotBlank(record.prompt_1__c)) {
            recordIds.add(record.Id);
        }
    }

    if (!recordIds.isEmpty()) {
        System.enqueueJob(new CursorWebhookJob(recordIds));
    }
}