import * as React from 'react'
import { CommitMessagPrompt } from './message'


type TargetedMessageEventData = {
    target?: string
    source: string,
    command: string,
    payload?: object
}

class Handler {
    iframe: HTMLIFrameElement
    iframeSource: string

    submitRunHandler?: () => void

    constructor(iframe: HTMLIFrameElement, source: string) {
        this.iframe = iframe
        this.iframeSource = source
        window.addEventListener('message', this.onMessage, false);
    }

    onMessage = (ev: MessageEvent) => {
        if (ev.source !== this.iframe.contentWindow) return
        try {
            const { data } = ev as MessageEvent<TargetedMessageEventData>
            if (data.source !== 'rstudio') return

            this[`handle_${data.command}`]?.(data.payload)

        } catch (e) {
            console.warn(e)
        }
    }

    handle_buttonClick({ id }) {
        console.log(`button click: ${id}`)
        if (id == 'requestEnclaveRun' && this.submitRunHandler) {
            this.submitRunHandler()
        }
    }

    handle_ready() {
        this.sendCommand('addButton', {
            id: 'requestEnclaveRun',
            style: { background: '#232cc5', color: 'white' },
            title: 'Run code in enclave',
            svg: `
                   <svg xmlns="http:www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-cloud-upload" viewBox="0 0 16 16">
                      <path fill-rule="evenodd" d="M4.406 1.342A5.53 5.53 0 0 1 8 0c2.69 0 4.923 2 5.166 4.579C14.758 4.804 16 6.137 16 7.773 16 9.569 14.502 11 12.687 11H10a.5.5 0 0 1 0-1h2.688C13.979 10 15 8.988 15 7.773c0-1.216-1.02-2.228-2.313-2.228h-.5v-.5C12.188 2.825 10.328 1 8 1a4.53 4.53 0 0 0-2.941 1.1c-.757.652-1.153 1.438-1.153 2.055v.448l-.445.049C2.064 4.805 1 5.952 1 7.318 1 8.785 2.23 10 3.781 10H6a.5.5 0 0 1 0 1H3.781C1.708 11 0 9.366 0 7.318c0-1.763 1.266-3.223 2.942-3.593.143-.863.698-1.723 1.464-2.383z"/>
                      <path fill-rule="evenodd" d="M7.646 4.146a.5.5 0 0 1 .708 0l3 3a.5.5 0 0 1-.708.708L8.5 5.707V14.5a.5.5 0 0 1-1 0V5.707L5.354 7.854a.5.5 0 1 1-.708-.708l3-3z"/>
                   </svg>
                `
        })
    }

    sendCommand(command: string, payload = {}) {
        this.iframe.contentWindow?.postMessage({
            source: 'kinetic', target: 'rstudio', command, payload,
        }, this.iframeSource);
    }

    disconnect() {
        window.removeEventListener('message', this.onMessage, false);
    }

}


export const RStudioIframe:React.FC<{ url: string, analysisId: number }> = ({ url, analysisId }) => {
    const [handler, setHandlerInstance] = React.useState<Handler | null>(null)

    // const onRun = async (message: string) => {
    //     return await submitCodeRun(analysisId, message)
    // }

    const setHandler = (el?: HTMLIFrameElement | null) => {
        if (el === handler?.iframe) return
        if (handler) handler.disconnect()
        if (el) {
            setHandlerInstance(new Handler(el, url))
        }
    }

    return (
        <div style={{ width: '100vw', height: '100vh' }}>
            <CommitMessagPrompt handler={handler} analysisId={analysisId} />
            <iframe style={ { border: 0, width: '100vw', height: '100vh' } } src = {url} ref={setHandler} />
        </div>
    )
}
