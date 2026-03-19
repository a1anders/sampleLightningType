import { LightningElement, api } from 'lwc';

export default class PdfUploadInput extends LightningElement {
    @api label = 'Upload PDF';
    @api required = false;
    @api recordId;

    _value;
    fileName;

    @api
    get value() {
        return this._value;
    }
    set value(val) {
        this._value = val;

        if (val && typeof val === 'object') {
            this.fileName = val.fileName || this.fileName;
        }
    }

    get acceptedFormats() {
        return ['.pdf'];
    }

    get uploadLabel() {
        return 'Select PDF File';
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;

        if (uploadedFiles && uploadedFiles.length > 0) {
            const file = uploadedFiles[0];

            this.fileName = file.name;

            const value = {
                recordId: file.documentId,
                objectApiName: 'ContentDocument'
            };

            this._value = value;

            this.dispatchEvent(
                new CustomEvent('valuechange', {
                    detail: { value },
                    bubbles: true,
                    composed: true
                })
            );
        }
    }
}