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
        <InputField label="Message" name="message" autoFocus />
    </EditingForm>
)

const SubmittedMessage:React.FC<{ onOk: () => void }> = ({ onOk }) => (
    <Box direction="column">
        <p>
            Thank you for submitting your script for review! Our team of engineers is now reviewing your code,
            and an email will be sent to your registered account once the review process is complete.
            To view and manage your script in your Kinetic dashboard, simply follow the link below or refresh your Kinetic page.
        </p>
        <Box justify="end">
          <Button primary onClick={onOk}>Back to Kinetic</Button>
        </Box>
    </ Box>
)

export const CommitMessagPrompt:React.FC<CommitMessagPromptProps> = ({ handler, analysisId }) => {
    const [wasSubmitted, setWasSubmitted] = useState(false)
    const { isEnabled, setEnabled, setDisabled } = useToggle()

    if (handler) handler.submitRunHandler = setEnabled
    const onModalHide = () => {
        setDisabled()
        setWasSubmitted(false)
    }
    const onOk = () => {
        onModalHide()
        window.opener.focus()
        self.close()
    }
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
            onHide={onModalHide}
            title={wasSubmitted ? 'Your Script was successfully submitted!' : 'Enter description of code to run'}
        >
            <Modal.Body>
                {wasSubmitted ? <SubmittedMessage onOk={onOk} /> : <Form onSubmit={onSubmit} />}
            </Modal.Body>
        </Modal>
    )
}
