/**
 * @description       : Trigger handler for Hippo HCP trigger
 * @author            : zoltan.nagy@veeva.com
 * @group             :
 * @last modified on  : 26-02-2025
 * @last modified by  : zoltan.nagy@veeva.com
 **/
public with sharing class VI_VEEV_HippoHCPTriggerHandler implements VI_VEEV_IFACE_TriggerHandler {
    public void onBeforeInsert(List<SObject> newItems) {
    }
    public void onBeforeUpdate(List<SObject> oldItems, List<SObject> newItems, Map<Id, SObject> oldItemsMap, Map<Id, SObject> newItemsMap) {
    }
    public void onBeforeDelete(List<SObject> oldItems) {
        VI_VEEV_HippoEventCloneHelper.deleteMedicalEventAttendees(oldItems);
    }
    public void onAfterInsert(List<SObject> newItems, Map<Id, SObject> newItemsMap) {
        VI_VEEV_HippoEventCloneHelper.createMedicalEventAttendees(newItemsMap);
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
