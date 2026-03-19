public with sharing class PdfSummarizerAction {
    public class PdfSummarizerRequest {
        @InvocableVariable(label='PDF File Input' required=true)
        public PdfUploadInputDTO fileUpload;
    }

    public class PdfSummarizerResult {
        @InvocableVariable(label='Summary of the PDF')
        public String summary;
    }

    @InvocableMethod(
        label='Summarize PDF for Agent'
        description='Takes a PDF file input from an agent and returns a summary.'
    )
    public static List<PdfSummarizerResult> summarize(List<PdfSummarizerRequest> requests) {
        List<PdfSummarizerResult> results = new List<PdfSummarizerResult>();

        if (requests == null || requests.isEmpty()) {
            return results;
        }

        for (PdfSummarizerRequest requestItem : requests) {
            PdfSummarizerResult result = new PdfSummarizerResult();

            try {
                if (requestItem == null ||
                    requestItem.fileUpload == null ||
                    String.isBlank(requestItem.fileUpload.recordId)) {
                    result.summary = 'No PDF file was provided.';
                    results.add(result);
                    continue;
                }

                result.summary = PdfSummarizerService.summarizePdf(
                    requestItem.fileUpload.recordId
                );
            } catch (Exception e) {
                result.summary = 'Unable to summarize PDF: ' + e.getMessage();
            }

            results.add(result);
        }

        return results;
    }
}