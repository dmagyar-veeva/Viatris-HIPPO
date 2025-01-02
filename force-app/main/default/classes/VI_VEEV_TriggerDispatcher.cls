/**
 * @description       : 
 * @author            : melita.calis@veeva.com
 * @group             : 
 * @last modified on  : 08-12-2021
 * @last modified by  : melita.calis@veeva.com
 * Modifications Log 
 * Ver   Date         Author                   Modification
 * 1.0   08-12-2021   melita.calis@veeva.com   Initial Version
 * 
**********************************************************************
*                                                                              
*               Confidentiality Information:
*
* This module is based on pre-existing content developed and owned 
* by Veeva Systems Inc.; this may only be used in connection with the 
* deliverable with which it was provided to Customer.
* 
* Copyright (c) 2019 Veeva Systems, Inc.  All Rights Reserved.
* 
**********************************************************************/
public class VI_VEEV_TriggerDispatcher {

    public static void run(VI_VEEV_IFACE_TriggerHandler handler) {

        if (handler.isDisabled()) {
            return;
        }

        if (Trigger.IsBefore )
        {
            if (Trigger.IsInsert)
                handler.onBeforeInsert(Trigger.new);
 
            if (Trigger.IsUpdate)
                handler.onBeforeUpdate(Trigger.old, Trigger.new, Trigger.oldMap, Trigger.newMap);
 
            if (Trigger.IsDelete)
                handler.onBeforeDelete(Trigger.old);
        }
         
        if (Trigger.IsAfter)
        {
            if (Trigger.IsInsert)
                handler.onAfterInsert(Trigger.new, Trigger.newMap);
 
            if (Trigger.IsUpdate)
                handler.onAfterUpdate(Trigger.old, Trigger.new, Trigger.oldMap, Trigger.newMap);
 
            if (trigger.IsDelete)
                handler.onAfterDelete(Trigger.old, Trigger.oldMap);
 
            if (trigger.isUndelete)
                handler.onAfterUndelete(Trigger.old, Trigger.oldMap);
        }
    }
}