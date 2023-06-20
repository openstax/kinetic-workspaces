import fetch from 'node-fetch'
import { getConfig } from './data.js'
import type { Analysis, AnalysisRunResponse } from '../definitions.js'

export async function getAnalysis(analysisId: number, ssoCookie: string): Promise<Analysis> {
    const config = await getConfig()

    const url = `${config.kineticURL}api/v1/researcher/analysis/${analysisId}`
    const cookie = `${config.ssoCookieName}=${ssoCookie}`
    console.log(`analysis fetch ${url} with sso: ${cookie}`)
    const resp = await fetch(url, {
        method: 'GET',
        headers: { cookie, "Content-Type": "application/json" }
    })

    if (!resp.ok) throw new Error(`unable to fetch analysis ${analysisId} (${resp.statusText})`)

    return await resp.json() as Analysis
}

export async function notifyStartEnclaveRun(analysisId: number, message: string): Promise<AnalysisRunResponse> {
    const config = await getConfig()
console.log('START', { message, analysisId })
    const resp = await fetch(`${config.kineticURL}api/v1/researcher/analysis/${analysisId}/runs`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${config.enclaveApiKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({ run: { message } }),
    })

    console.log(resp.status, config.enclaveApiKey)

    if (!resp.ok) throw new Error('unable to start enclave run')

    return await resp.json() as AnalysisRunResponse
}
