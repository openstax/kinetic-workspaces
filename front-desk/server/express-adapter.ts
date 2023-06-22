import * as express from 'express'
import { IS_PROD, getConfig } from './data.js'
import type { StatusParams } from '../definitions.js'
import { newRpcError, newRpcSuccess } from './rpc.js'
import { EditorService } from './service.js'


export const handler = async (req: express.Request, res: express.Response) => {
    try {
        const config = await getConfig()
        const params = req.body as StatusParams

        console.log('RPC req', JSON.stringify(params, null, 4))
        const service = new EditorService({
            config,
            analysisId: params.analysisId,
            documentStatus: params.documentStatus,
            getCookie(name: string) {
                // when running in dev mode, we can't access the coookie since it's using the local port
                if (!IS_PROD && name == 'stubbed_user_uuid') return '00000000-0000-0000-0000-000000000001'
                return req.cookies[name]
            },
            setCookie(name: string, value: string) {
                console.log("SET COOKIE", name, value, config.dnsZoneName)
                res.cookie(name, value, {
                    httpOnly: true, secure: false, encode: String, domain: config.dnsZoneName,
                })
            },
        })
        if (params.archiveMessage) {
            const id = await service.archive(params.archiveMessage)
            return res.status(200).send(newRpcSuccess({ id }))
        }

        const result = await service.update()
        return res.status(200).send(newRpcSuccess(result))

        // const encoded = req.cookies[config.ssoCookieName] || 'eyJhbGciOiJkaXIiLCJlbmMiOiJBMjU2R0NNIn0..8hYFUqwAeSeafGAI.uTL9RVxHVVR13jqF0EqlVNKsiBcjNQxon9WpN6eDnosi652Ve6odUmPs675RJqclL1e_v740gp2z3FfbnSJoW_6e2g9m_1LQZD6EJi1-ZczxYBjuSk-MHWvkHm-XNEvuK2JHkyYYQglSTCvnvTe7DupvihvstRAlTF7uIfBrYUXOGTksbbheSt9T20DeYigbZBG-5N54BHlO2vSfQyDmibJqlfnMUR4_hBdoSW9YjuDOMKgxazKu0lRLDyjNBR5c2Vr69ziTFaJzf7smZ2ndMxCbl7OJBRTs-IhkF7ylmsmK4km5zYSGSgFNNiQy-ZqPIMmF7WAGDBKa5BqrUS775YV9p1MBP-JRseohbjas9LP7-ydH7R1wl2DrFOhVujzlA-HALe1jGDIRAlZtftr6YJCRoYAAlOg5XU11ggJn9Tbf4zd1dHtNk58y_C38e7059h0NklYhLrhJXmkdb1tDMs8AyAeXaxTJ74Y_h9eBIqJEi_02nODzfuUQXWf0fr19KAWqFtI_hdiNBxd7otzyM28FEsrFd908MdlFrCBEAjdmpX_dd3rtCs9IkVWF4xsWqWtr0a_wTTRWwG-EaDcX21Ob2mfi6Oju1r70Z_dBiB5Jr0EsvZYSbegNCnjqUqz8R4pHWsiKQizRhPZOwLc6oU6gfBY28bYsQc-iv7W8cSRzrm180YeHY_QqyJtmzx4hoNTinLBJraOEHo1hC34TAOIA6wxkxvA_8R3cdJsa3ixy4mshpqKtJ7yKyVb-xaogAMMc1Sk5axWJRnt-tE3ym_4uJ1rd6Jybls6uwJFf4WYCUMdReckQM7t9eLhL_FFhWoLxCvHzsO8v5OfbFtcStCHYc_xsNKzoJBWcW8Ugudu1vjNKfT9g09pUHL7-brFEAo19ht9d7fAbQEKZzJu3IlDY3Olhm3k6xRbkQVwXc0xeb6KTMef_VpJkNkaUhId6avHKIZ0OUJyJKRQTLsa_AusPcDTbsLfcZcOTMnPubOxiJjOPeEpafJOSMxrPvEKR8qNDZU-w7D2SZTVheLQk0PnTpiGvLQwSmIgF3jmP8bGoYsC_IjzIjFRriaV2RcLXY8daL7WMdP1kfEl6IiKKBpof5UyoeUfyI7kIktaTdu9be309I2RXVcFAiDt_WEWjeWqDkxLpOAZPQqTYHAyuH3xGV2J14RkqOtdfadnwO8kQPzrIrcbgmg63K2vsaAUC5CQ1mcLs28kAv3SFS4YGT18se8nRDXbcnNizr5KC4C0A4C4pOJmAj9w38gEY-fYMADf64lW6Tj_Opkt9XNgX_cT2VvWFU5cxCOKukc9cwwA3gYg3Yvtbw1gkANrQ7LtIyDZ9AX8a3zM6697S0hOakPgLa5-W_uOkY5cjQ37McxtIGi3hbGg3jUBw7VkQGm10cKVkoR5FN0nDQU8YoHhze-CJuVjTv1iWmTxFf-15_EYD3ifDI2VUXvERjPg.rGZq7rnr8Ln3mtZO1XXGmA'
        // if (!encoded) throw new Error('unauthorized')
        // const user = await getUserFromCookieValue(encoded)
        // if (!user) { return res.status(403).send(newRpcError('unauthorized')) }


        // const analysis = await getAnalysis(params.analysisId, req.body.cookies[config.ssoCookieName])
        // if (!analysis) { return res.status(403).send(newRpcError('unauthorized')) }

        // const status = await updateEditorState(analysis, params.isDocumentVisible)
        // if (isRPCSuccess(status) && status.isActive) {
        //     if (!req.cookies['rs-csrf-token']) {
        //         res.cookie('rs-csrf-token', randomUUID())
        //     }
        //     res.cookie('user-id', await newEditorCookie(), {
        //         httpOnly: true, secure: false, encode: String, domain: config.dnsZoneName,
        //     })
        // }
        // return res.status(200).send(status)
    } catch (err) {
        return res.status(500).send(newRpcError(err as Error))
    }
}
