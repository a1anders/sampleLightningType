public with sharing class PdfSummarizerService {
    private static final String PROMPT_TEMPLATE_API_NAME = 'Agentforce_Employee_Agent_PDF';

    public class PdfSummarizerException extends Exception {}

    public static String summarizePdf(String contentDocumentId) {
        if (String.isBlank(contentDocumentId)) {
            throw new PdfSummarizerException('A ContentDocument Id is required.');
        }

        ContentDocument doc;
        try {
            doc = [
                SELECT Id, Title, FileType, LatestPublishedVersionId
                FROM ContentDocument
                WHERE Id = :contentDocumentId
                LIMIT 1
            ];
        } catch (QueryException e) {
            throw new PdfSummarizerException(
                'Could not find a Salesforce File for ContentDocument Id: ' + contentDocumentId
            );
        }

        if (doc.FileType == null || doc.FileType.toUpperCase() != 'PDF') {
            throw new PdfSummarizerException(
                'The selected file must be a PDF. Found file type: ' + String.valueOf(doc.FileType)
            );
        }

        try {
            ConnectApi.WrappedValue fileValue = new ConnectApi.WrappedValue();
            fileValue.value = new Map<String, String>{
                'id' => (String)doc.Id,
                'type' => 'ContentDocument'
            };

            Map<String, ConnectApi.WrappedValue> inputParams =
                new Map<String, ConnectApi.WrappedValue>{
                    'Input:File' => fileValue
                };

            ConnectApi.EinsteinPromptTemplateGenerationsInput request =
                new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            request.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            request.additionalConfig.applicationName = 'PromptBuilderPreview';
            request.isPreview = false;
            request.inputParams = inputParams;

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    PROMPT_TEMPLATE_API_NAME,
                    request
                );

            if (response == null ||
                response.generations == null ||
                response.generations.isEmpty() ||
                String.isBlank(response.generations[0].text)) {
                throw new PdfSummarizerException('The prompt template returned no summary.');
            }

            return response.generations[0].text;
        } catch (Exception e) {
            throw new PdfSummarizerException(
                'An error occurred while generating the PDF summary: ' + e.getMessage()
            );
        }
    }
}