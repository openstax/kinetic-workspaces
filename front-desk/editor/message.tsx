import React, { useState } from 'react'
import {
    Modal
} from '@nathanstitt/sundry/modal'
import { useToggle } from '@nathanstitt/sundry/base'
import { EditingForm, FormSubmitHandler, InputField } from '@nathanstitt/sundry/form'
import { submitCodeRun } from '../server/rpc'
import { Button, Box } from '@nathanstitt/sundry/ui'



type CommitMessagPromptProps = {
    analysisId: number
    handler: null | {
        submitRunHandler?: () => void
    }
}

type FormVals = {
    message: string
}

const Form: React.FC<{ onSubmit: FormSubmitHandler<FormVals> }> = ({ onSubmit }) => (
    <EditingForm
        showControls name="message"
        saveLabel="Run"
        submittedMessage='Script has been scheduled to run'
        defaultValues={{ message: '' }}
        onSubmit={onSubmit}
    >
        <InputField label="Message" name="message" />
    </EditingForm>
)

const SubmittedMessage:React.FC<{ onOk: () => void }> = ({ onOk }) => (
    <Box direction="column">
        <h3>Code was submitted successfully</h3>
        <Button primary onClick={onOk}>OK</Button>
    </ Box>
)

export const CommitMessagPrompt:React.FC<CommitMessagPromptProps> = ({ handler, analysisId }) => {
    const [wasSubmitted, setWasSubmitted] = useState(false)
    const { isEnabled, setEnabled, setDisabled } = useToggle()

    if (handler) handler.submitRunHandler = setEnabled

    const onSubmit:FormSubmitHandler<FormVals> = async (vals, fc) => {
        if (!vals.message) { return }

        const result = await submitCodeRun(analysisId, vals.message)
        if (result.error) {
            fc.setFormError(result.message)
        } else {
            setWasSubmitted(true)
        }
    }

    return (
        <Modal
            show={isEnabled}
            onHide={setDisabled}
            title="Enter description of code to run"
        >
            <Modal.Body>
                {wasSubmitted ? <SubmittedMessage onOk={setDisabled} /> : <Form onSubmit={onSubmit} />}
            </Modal.Body>
        </Modal>
    )
}
