/// <reference types="@emotion/react/types/css-prop" />
import './style.scss'
import React from 'react'
import { createRoot } from 'react-dom/client'
import {
    ErrorTypes, useDocumentVisibilityState, useInterval,
} from '@nathanstitt/sundry/base'
import { Pending, ErrorMessage } from '@nathanstitt/sundry/ui'
import type { EditorState } from '../definitions.js'
import { isRPCError, updateWorkspaceStatus } from '../server/rpc.js'
import { RStudioIframe } from './iframe.js'


export function Editor() {
    const analysisId = Number((location?.hash?.match(/(\d+)$/) || [0])[0])

    const [error, setError] = React.useState<ErrorTypes | null>(analysisId ? null : new Error('invalid or missing editor ID'))
    const [editor, setEditor] = React.useState<EditorState | null>(null)

    const visibilityState = useDocumentVisibilityState()

    useInterval(async () => {
        if (!analysisId) return

        const update = await updateWorkspaceStatus({ analysisId, documentStatus: visibilityState ? visibilityState : 'visible' })
        console.log({ update })

        if (isRPCError(update)) {
            setError(update)
        } else {
            setError(null)
            setEditor(update.data)
        }
    }, 5_0000, { immediate: true })

    if (error) return <ErrorMessage css={{ marginTop: '100px' }} error={error} />
    if (!editor?.isActive) return <Pending css={{ marginTop: '100px' }} name="editor" />

    return (
        <RStudioIframe analysisId={analysisId} url={`https://${editor?.hostName}/`} />
    )
}


const whenDomReady = (fn: () => void) => {
    if (document.readyState === "complete" || document.readyState === "interactive") {
        setTimeout(fn, 1)
    } else {
        document.addEventListener("DOMContentLoaded", fn)
    }
}

whenDomReady(() => createRoot(document.getElementById('root')!).render(<Editor />))
