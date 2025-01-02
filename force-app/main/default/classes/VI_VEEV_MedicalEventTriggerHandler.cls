/**
 * @description       : Trigger handler for Medical Event trigger
 * @author            : daniel.magyar@veeva.com
 * @group             :
 * @created on        : 09-09-2024
 **/
public with sharing class VI_VEEV_MedicalEventTriggerHandler implements VI_VEEV_IFACE_TriggerHandler {
    public void onBeforeInsert(List<SObject> newItems) {
    }

    public void onBeforeUpdate(List<SObject> oldItems, List<SObject> newItems, Map<Id, SObject> oldItemsMap, Map<Id, SObject> newItemsMap) {
        VI_VEEV_HippoEventCloneHelper.checkAttendeeCallSubmission(newItems, oldItemsMap);
    }

    public void onBeforeDelete(List<SObject> oldItems) {
    }

    public void onAfterInsert(List<SObject> newItems, Map<Id, SObject> newItemsMap) {
    }

    public void onAfterUpdate(List<SObject> oldItems, List<SObject> newItems, Map<Id, SObject> oldItemsMap, Map<Id, SObject> newItemsMap) {
    }

    public void onAfterDelete(List<SObject> oldItems, Map<Id, SObject> oldItemsMap) {
    }

    public void onAfterUndelete(List<SObject> oldItems, Map<Id, SObject> oldItemsMap) {
    }

    public Boolean isDisabled() {
        return false;
    }
}
