PREWORK:

Create the Prompt Template

Type: Flex

Input: File (ContentDocument)

Name: Agentforce Employee Agent PDF

Model: (any model that supports multimodal capabilities)

Prompt: Parse the file and return Order Number, Completion Date, Claim Date, Status, and Total Amount.

Add the Apex classes in this order.

PdfUploadInputDTO
PdfSummarizerService
PdfSummarizerAction

Add the LWC.

PdfUploadInputDTO
PdfSummarizerService
PdfSummarizerAction

Add the Lightning Type.

Add a folder called lightningType.
force-app/
└── main/
     └── default/
          ├── lightningTypes/

Create the Lightning Type Bundle

Creating a subfolder for the type and putting the required JSON files inside it. 

In source format, the bundle is just the folder plus its config files. Schema.json is required; editor.json and renderer.json are optional and live in a channel subfolder such as lightningDesktopGenAi.

This sample only uses editor.json, because it only requires a Lightning Type for the input. renderer.json is for the output.

force-app/
└── main/
    └── default/
        └── lightningTypes/
            └── pdfUploadInputType/
                ├── schema.json
                └── lightningDesktopGenAi/
                    └── editor.json

Create the files first. Then paste the code in.

Create the Employee Agent

Name: Agentforce Employee Agent

Description: Your sole purpose is to parse PDF files and return content.

Role: You are an Agentforce Employee Agent. You accept uploads from users and parse them.


Create the Topic

Name: PDF Upload and Analysis

Classification Description: PDF file upload and analysis requests

Scope: PDF files, document upload, file analysis, document parsing, file summarization

Instruction: 
When a user wants to analyze a PDF document:
1. Present the file upload interface to collect the PDF file
2. Gather the record ID and object API name for context
3. Execute the PDF Summarizer action to process the uploaded file
4. Present the parsed content and analysis results to the user in a clear, organized format
Always confirm the file was successfully uploaded before processing.

Create the Action

Reference Action Type: Apex
Reference Action Category: Invocable Method
Reference Action: Summarize PDF for Agent

Name: PDF Summarizer

Agent Action Instructions: Use this action to parse and analyze the PDF file uploaded by the user. Execute after confirming the file upload is complete.
Loading Text: Thinking…

Input
Instructions: Please upload the PDF file you want to analyze.
Require input (checked)
Collect data from user (checked)
Input rendering: PdfUploadType

Output:
Instructions: Here are the results from your PDF analysis: {!$Output}
Show in conversation (checked)
Output Rendering: Rich Text

NOTES:

Lightning Type - The Lightning Type defines the schema of the custom input used by Agentforce. In this design, the type represents a small object containing the uploaded file metadata, specifically the ContentDocument id that Apex needs to process the PDF. Apex-based Lightning Types derive their schema from Apex classes whose members are annotated with @AuraEnabled.

What it does in this solution:
Provides a structured input contract for the agent action.
Uses the Apex DTO as the canonical shape.
Allows the agent UI to render a custom input component instead of a plain generic object editor.

Important learnings:
The Lightning Type was not the problem and did not need to be changed once the schema was correct.
The runtime contract is object-based, even if some logs render the value looking like JSON text.

The simplest stable contract was:
recordId
objectApiName

For this use case, recordId is the ContentDocument.Id of the uploaded PDF.

Apex DTO (PdfUploadInputDTO)
This class is the shared schema between the Lightning Type, the LWC, and the invocable Apex action. It represents the uploaded file selection in a structured way. Apex classes can be used as complex types for custom agent action inputs and outputs.

Responsibilities
Defines the shape of the input object.
Carries the uploaded file reference from the UI into the Apex action.
Keeps the interface strongly typed instead of relying on raw JSON strings.
Important learnings

Duplicating the DTO in multiple Apex classes is a bad idea; one top-level DTO should serve as the single contract.
The DTO should be minimal. In this implementation:
recordId = Salesforce File / ContentDocument.Id
objectApiName = ContentDocument

Keeping the DTO stable made it possible to fix the LWC and Apex independently without touching the Lightning Type.

Input LWC (pdfUploadInput)
This LWC replaces the default Agentforce input UI with a custom file upload experience. Custom Lightning Types can override the agent action input UI through an LWC, and the component must communicate value changes back to the agent runtime.

Responsibilities:
Renders the PDF upload control.
Uploads the file into Salesforce Files.
Receives the resulting documentId from lightning-file-upload.
Emits the DTO object back to Agentforce using the expected input-binding pattern.

Key implementation details:
The component exposes a public value property, not a custom property like fileUpload.
After upload completes, it dispatches a valuechange event with detail.value.
The uploaded file event returns a documentId, which becomes the DTO’s recordId.
lightning-file-upload is the right control because it creates a real Salesforce File and returns the ContentDocument id when the upload finishes.

The first version mixed two patterns:
custom HTML drag/drop
JS written for lightning-file-upload
That mismatch meant the event handler never fired.

Timing matters: the agent should only receive the value after upload is complete.

The correct Agentforce binding pattern is:
public value
valuechange
detail.value
Passing a plain object worked better than forcing JSON stringification.

Invocable Apex Action (PdfSummarizerAction)
This class is the Agentforce action entry point. Agentforce can expose Apex logic as custom actions when the method is annotated with @InvocableMethod. The invocable wrapper defines the action’s formal input and output shape.

Responsibilities:
Accepts the structured file input from Agentforce.
Extracts the ContentDocument id from the DTO.
Calls the service layer to do the real work.
Returns a structured output object containing the summary.
Why the wrapper pattern matters

Agentforce actions expect a clean action boundary.
The invocable class should be thin and orchestration-focused.
Business logic belongs in a separate service class, which keeps the action easier to test and reason about.
Important learnings

The invocable method should handle a list of requests, even if the current UI submits one at a time.
AuraHandledException is the wrong exception type in this context; it is intended for Aura/Visualforce-style handling and caused the System.LimitException you saw. In this architecture, errors are caught inside the invocable path and returned as output text instead of being thrown to the agent runtime.
Returning a readable failure string in the output object made debugging in Agentforce much easier than letting the action fail generically.

Service Layer (PdfSummarizerService)
This class contains the business logic for validating the file and invoking the prompt template. It isolates Prompt Builder integration details from the invocable action wrapper. Prompt templates can be invoked from Apex through the Connect API / Einstein LLM generation APIs.

Responsibilities:

Validates the incoming ContentDocument id.
Queries Salesforce Files metadata.
Confirms the file is a PDF.
Builds the prompt-template input payload.
Calls the prompt template by API name.
Extracts and returns the generated summary text.

Important learnings:

The prompt template input key must match the prompt resource API name in the format Input:<resourceApiName>. This was one of the biggest gotchas. The runtime error naming Input:File was the clue that the prompt resource API name was File, even though the underlying Salesforce object was ContentDocument.

A real queried ContentDocument sObject was not the correct runtime payload for the prompt input.
The file input needed to be sent as a wrapped value representing the file reference, not just a raw sObject instance.

The applicationName field in additionalConfig must reference a valid registered AI application. Using an arbitrary string caused the “Application Name is a required field providing existing registered ai application” error.

Prompt Template (Agentforce_Employee_Agent_PDF):
This Prompt Builder Flex template performs the actual PDF interpretation. Apex is only responsible for delivering the right file reference and reading the model output; the parsing instructions live in the prompt template. Prompt Builder Flex templates are designed for this sort of dynamic input-driven generation flow.

Responsibilities:
Accepts a file-oriented input resource.
Reads the PDF content through Salesforce’s prompt infrastructure.
Applies your instructions for extracting the desired fields.
Returns the natural-language or structured result consumed by the agent.

Important learnings:
The prompt resource’s API name matters as much as its data type.
“Input data type = ContentDocument” does not necessarily mean Apex should pass a raw ContentDocument record as the prompt value.
Runtime errors from the prompt invocation were the fastest way to identify the exact input name and payload mismatch.

End-to-end runtime flow:
The agent asks the user for a PDF.
The custom input LWC renders inside the agent conversation.
The user uploads a PDF through lightning-file-upload.
Salesforce stores the file as a ContentDocument.
The LWC receives the uploaded file’s documentId.
The LWC packages that id into the DTO and emits valuechange.
Agentforce passes that typed input into the Apex invocable action.
The invocable action calls the service layer.
The service validates the file and invokes the Prompt Builder template.
The prompt processes the PDF and returns text.
The invocable action returns the summary as structured output.
Agentforce displays the parsed result in the conversation.

Design choices that made this architecture work

Stable contract: keeping the Lightning Type and DTO stable reduced moving parts.

Thin action / fat service: the invocable method stayed simple while the prompt-call complexity lived in one service class.

Native file upload: using lightning-file-upload guaranteed a real Salesforce File and returned the ContentDocument id needed downstream.

Structured input/output: using complex Apex types kept the action easier to configure in Agentforce and easier to debug than loose strings.

Prompt Builder separation: extraction logic lives in the prompt, not hardcoded in Apex, which makes prompt behavior easier to refine later without redesigning the action boundary.

Practical Gotchas:

AuraHandledException is not appropriate in an Agentforce invocable path; catch errors and return them safely from the action instead.

lightning-file-upload is asynchronous, so the agent should not expect usable input until upload completion.

The custom input LWC should use the Agentforce-style binding pattern with value and valuechange.
Prompt input resource names are case-sensitive and must match the Input:<resourceApiName> key used in Apex.
A prompt input typed around Salesforce files may still require a specialized wrapped runtime payload rather than a raw queried sObject.
