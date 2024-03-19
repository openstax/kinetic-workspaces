import React, { useEffect } from 'react'
import { createRoot } from 'react-dom/client'
import { whenDomReady } from '../lib/util'
import { REQUEST_KINETIC_DETAILS } from '../editor/iframe'
import './styles.scss'

function resizeIFrameToFitContent( ev: any  ) {
    const frame = ev.target

    frame.style.height = (frame.contentWindow.document.body.scrollHeight + 20) + 'px';
}


const infoForUrl = async (url: string) => {
    const resp = await fetch(url, { mode: 'cors', method: 'GET' })
    if (!resp.ok) {
        showError(resp.statusText)
        return ''
    }
    return await resp.text()
}

function showError(msg: string) {
    const root = document.getElementById('root')
    if (root) root.innerHTML = `<h1>Error: ${msg}</h1>`
}


export function Tutorial({ tutorials }: { tutorials: string[] }) {
    // useEffect(() => {
    //     // or, to resize all iframes:
    //     var iframes = document.querySelectorAll("iframe");
    //     for (var i = 0; i < iframes.length; i++) {
    //         resizeIFrameToFitContent(iframes[i]);
    //     }
    // },[])

    return (
        <div>
            {tutorials.map((html, i) => <iframe key={i} srcDoc={html} onLoad={resizeIFrameToFitContent} />)}
        </div>
    )

}

whenDomReady(() => {
    window.top?.postMessage(REQUEST_KINETIC_DETAILS)

    window.addEventListener('message', (ev) => {
        console.log(ev)
        const payload = JSON.parse(ev.data)
        if (payload.analysisId && payload.url) {

            fetch(payload.url, { credentials: 'include' }).then(async (resp) => {
                if (!resp.ok) {
                    showError(resp.statusText)
                }

                const data = await resp.json()
                console.log(data)

                const tutorials = await Promise.all(data.info_urls.map(infoForUrl))

                console.log(tutorials)
                createRoot(document.getElementById('root')!).render(<Tutorial tutorials={tutorials}/>)

            })
        }

    }, false);


})

console.log('tutorial boot')
