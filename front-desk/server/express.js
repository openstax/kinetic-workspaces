import * as fs from 'fs'
import * as path from 'path'
// import { fileURLToPath } from 'url'
import express from 'express'
import { createServer as createViteServer } from 'vite'
//import { newRpcError } from '../rpc.js'
import cookieParser from 'cookie-parser'
//const __dirname = path.dirname(fileURLToPath(import.meta.url))

async function createServer() {
    const app = express()
    const port = process.env.PORT || 5050

    // Create Vite server in middleware mode and configure the app type as
    // 'custom', disabling Vite's own HTML serving logic so parent server
    // can take control
    const vite = await createViteServer({
        server: { middlewareMode: true },
        appType: 'custom'
    })

    // Use vite's connect instance as middleware. If you use your own
    // express router (express.Router()), you should use router.use
    app.use(vite.middlewares)

    app.use(express.json())
    app.use(cookieParser())

    app.put('/status', async (req, res) => {
        const { handler } = await vite.ssrLoadModule('/server/express-adapter')
        try {
            handler(req, res)
        } catch (err) {
            vite.ssrFixStacktrace(err)
            console.warn(err)
            return res.status(500).send({ error: true })
        }
    })

    app.get('/editor/', async (req, res) => {
        const url = req.originalUrl
        const template = fs.readFileSync(path.resolve('index.html'), 'utf-8')

        const html = await vite.transformIndexHtml(url, template)

        res.set('Content-Type', 'text/html').send(html)
    })

    app.listen(port)
    // eslint-disable-next-line no-console
    console.log(`Server running at http://localhost:${port}`)
}

createServer()
