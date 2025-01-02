public with sharing class VproApprovalProcessOverrideController {
    public ProcessInstanceWorkitem theApprovalRequest { get; set; }
    private List<String> approvalRequestFields = new List<String>();

    public Boolean isMedicalEventRecord { get; set; }
    public String sObjectTypeLabel { get; set; }
    public String approvalComments { get; set; }
    public final System.Pagereference APPROVAL_REQUEST_DETAIL_PAGE;
    // Get User's Language
    public String getUserLang() {
        return UserInfo.getLanguage();
    }
    public VproApprovalProcessOverrideController(ApexPages.StandardController stdController) {
        // approvalRequestFields.add('ActorId');
        // approvalRequestFields.add('OriginalActorId');
        approvalRequestFields.add('ProcessInstance.TargetObjectId');
        approvalRequestFields.add('ProcessInstance.TargetObject.Name');
        approvalRequestFields.add('ProcessInstanceId');
        stdController.addFields(approvalRequestFields);
        this.theApprovalRequest = (ProcessInstanceWorkitem) stdController.getRecord();
        System.debug(this.theApprovalRequest);
        isMedicalEventRecord = Schema.Medical_Event_vod__c.SObjecttype == this.theApprovalRequest.ProcessInstance.TargetObjectId.getSobjectType();
        sObjectTypeLabel = this.theApprovalRequest.ProcessInstance.TargetObjectId.getSobjectType().getDescribe().getLabel();
        APPROVAL_REQUEST_DETAIL_PAGE = new Pagereference('/' + this.theApprovalRequest.Id);
        System.debug('Constructor:START_PAGE=' + APPROVAL_REQUEST_DETAIL_PAGE);
    }

    public Pagereference approveRequest() {
        approveRejectRequest('Approve', approvalComments);
        return new Pagereference('/' + this.theApprovalRequest.ProcessInstance.TargetObjectId);
    }
    public Pagereference rejectRequest() {
        approveRejectRequest('Reject', approvalComments);
        return new Pagereference('/' + this.theApprovalRequest.ProcessInstance.TargetObjectId);
    }

    private void approveRejectRequest(String action, String comments) {
        System.debug('ApprovalRejectionComments:' + comments);
        //Class used for Approving Record
        Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
        if (!isMedicalEventRecord) {
            System.debug('Not an EM Event record..proceeding to approve');
            req.setComments(comments);
            //Approve or Reject Record
            req.setAction(action);
            req.setWorkitemId(theApprovalRequest.Id);
            // Submit the request for approval
            Approval.ProcessResult result = Approval.process(req);
        } else {
            System.debug('Is an EM Event record..proceeding to simply forward to detail page');
        }
        approvalComments = null;
    }

    public Pagereference cancelRequest() {
        System.debug('cancelRequest::START_PAGE = ' + APPROVAL_REQUEST_DETAIL_PAGE);
        return APPROVAL_REQUEST_DETAIL_PAGE;
    }
}