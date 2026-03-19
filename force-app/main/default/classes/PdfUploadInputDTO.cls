@JsonAccess(serializable='always' deserializable='always')
global class PdfUploadInputDTO {
    @AuraEnabled
    global String recordId;

    @AuraEnabled
    global String objectApiName;
}