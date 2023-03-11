import * as React from 'react'
import { createRoot } from 'react-dom/client'
import {
    ErrorTypes, Pending, ErrorMessage, useEventListener,
    useDocumentVisibilityState, useInterval,
} from '@nathanstitt/sundry'
import type { EditorState } from './definitions.js'
import { isRPCError, updateWorkspaceStatus } from './rpc.js'


export const DatePicker: React.FC<{ yyyy_mm_hh: string, onChange: (yyyy_mm_hh: string) => void }> = ({ yyyy_mm_hh, onChange }) => {
    return null
}


export function Editor() {
    const analysisId = Number((location?.hash?.match(/(\d+)$/) || [0])[0])

    const [error, setError] = React.useState<ErrorTypes | null>(analysisId ? null : new Error('invalid or missing editor ID'))
    const [editor, setEditor] = React.useState<EditorState | null>(null)

    const visibilityState = useDocumentVisibilityState()

    // React.useEffect(() => {
    //     window.addEventListener("beforeunload", function (e) {
    //                  updateWorkspaceStatus({ analysisId, documentStatus: 'closed' })
    //         return 'useuse?'
    //     });
    // }, [])
    const obu = React.useCallback(() => {
        updateWorkspaceStatus({ analysisId, documentStatus: 'closed' })
        return 'use'
    }, [])

    useEventListener('beforeunload', obu, { target: window })

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

    console.log(editor, error)

    if (error) return <ErrorMessage css={{ marginTop: '100px' }} error={error} />
    if (!editor?.isActive) return <Pending css={{ marginTop: '100px' }} name="editor" />



    return (
        <div style={{ width: '100vw', height: '100vh' }}>
            <iframe style={{ border: 0, width: '100vw', height: '100vh' }} src={`https://${editor?.hostName}/`} />
        </div>
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
