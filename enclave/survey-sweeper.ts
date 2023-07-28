import type { Handler } from 'aws-lambda'
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3"
import { createWriteStream, mkdirSync } from 'node:fs'
import { Readable } from 'stream'
import { spawn } from 'child_process'
import process from 'process'

async function cmd(...command: string[]) {
    return new Promise((resolve, reject) => {
        const p = spawn(command[0], command.slice(1), {
            cwd: '/tmp'
        })
        p.stdout.on("data", (x) => {
            process.stdout.write(x.toString());
        });
        p.on('exit', (s) => {
            if (s == 0) {
                resolve(s)
            } else {
                reject(`exit status: ${s}`)
            }
        })
        p.stderr.on("data", (x) => {
            process.stderr.write(x.toString());
        });
    })
}
type Args = {
    survey_id: string
    start_date: string
    end_date: string
}
export const handler: Handler<Args> = async (args) => {
    console.log(args)
    const { survey_id, start_date, end_date } = args
    const s3 = new S3Client({ region: 'us-east-1' })
    try {
        const b = {
            Bucket: process.env.SCRIPT_BUCKET,
            Key: process.env.R_SCRIPT_PATH,
        }
        const { Body: body } = await s3.send(new GetObjectCommand(b))
        if (body instanceof Readable) {
            const stream = createWriteStream('/tmp/fetch-and-process.R')
            body.pipe(stream);
        } else {
            throw new Error('R script: no body, or not readable')
        }

        const ROutput = await cmd(
            '/usr/bin/R', '-f', '/tmp/fetch-and-process.R', '--args',
            survey_id, start_date, end_date,
        )
        const response = {
            statusCode: 200,
            ROutput,
            body: JSON.stringify({ hello: 'Hello from Lambda!' }),
        }
        return response;
    } catch (err) {
        console.warn(err, err.stack)
        return {
            statusCode: 500,
            body: JSON.stringify({ error: err.toString(), stack: err.stack }),
        }
    }
}
