/**
 * @description       : Trigger handler for Hippo Event trigger
 * @author            : daniel.magyar@veeva.com
 * @group             :
 * @last modified on  : 10-12-2023
 * @last modified by  : daniel.magyar@veeva.com
 **/
public with sharing class VI_VEEV_HippoInteractionTriggerHandler implements VI_VEEV_IFACE_TriggerHandler {
    public void onBeforeInsert(List<SObject> newItems) {
    }
    public void onBeforeUpdate(List<SObject> oldItems, List<SObject> newItems, Map<Id, SObject> oldItemsMap, Map<Id, SObject> newItemsMap) {
    }
    public void onBeforeDelete(List<SObject> oldItems) {
    }
    public void onAfterInsert(List<SObject> newItems, Map<Id, SObject> newItemsMap) {
        VI_VEEV_HippoEventCloneHelper.insertMedicalEventAttendeesFromInteraction(newItemsMap);
    }
    public void onAfterUpdate(List<SObject> oldItems, List<SObject> newItems, Map<Id, SObject> oldItemsMap, Map<Id, SObject> newItemsMap) {
        VI_VEEV_HippoEventCloneHelper.upsertMedicalEventAttendeesFromInteraction(oldItemsMap, newItemsMap);
    }
    public void onAfterDelete(List<SObject> oldItems, Map<Id, SObject> oldItemsMap) {
    }
    public void onAfterUndelete(List<SObject> oldItems, Map<Id, SObject> oldItemsMap) {
    }
    public Boolean isDisabled() {
        return false;
    }
}