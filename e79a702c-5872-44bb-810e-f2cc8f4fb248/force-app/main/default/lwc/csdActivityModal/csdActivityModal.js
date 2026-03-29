import { api } from 'lwc';
import LightningModal from 'lightning/modal';

export default class CsdActivityModal extends LightningModal {
    @api objectApiName;
    @api whatId;
    @api defaultFieldValues = {};
    @api modalTitle = 'New Activity';

    get isTask() {
        return this.objectApiName === 'Task';
    }

    get isEvent() {
        return this.objectApiName === 'Event';
    }

    get defaultStatus() {
        return this.defaultFieldValues?.Status || '';
    }

    get defaultType() {
        return this.defaultFieldValues?.Type || '';
    }

    get hasDefaultStatus() {
        return !!this.defaultFieldValues?.Status;
    }

    get hasDefaultType() {
        return !!this.defaultFieldValues?.Type;
    }

    handleSuccess(event) {
        this.close({ success: true, recordId: event.detail.id });
    }

    handleCancel() {
        this.close({ success: false });
    }

    handleSubmit(event) {
        event.preventDefault();
        const fields = { ...event.detail.fields };

        if (this.defaultFieldValues) {
            for (const [key, value] of Object.entries(this.defaultFieldValues)) {
                if (!fields[key]) {
                    fields[key] = value;
                }
            }
        }

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }
}
