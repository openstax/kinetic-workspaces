// import {
//     EC2Client, RunInstancesCommand,
//     // RunInstancesCommandInput, DescribeInstancesCommand, Instance,
//     // TerminateInstancesCommand,
// } from '@aws-sdk/client-ec2'
import { EC2Client, RunInstancesCommand } from "@aws-sdk/client-ec2";

import { Handler } from 'aws-lambda'

import type { EventInput, AnalyzePayload } from './types'

// @ts-ignore
import userData from './ec2-user-data.sh'

type Event = {
    input: EventInput
    token: string
}

export const handler: Handler<Event> = async ({ input, token }) => {
const payload:AnalyzePayload = {
        task_token: token,
        region: process.env.AWS_REGION || 'us-east-1',
        base_image: process.env.BASE_IMAGE || '',
        ...input
    }

    console.log({ payload })

    const script = userData
        .replace(/SCRIPT_XXXX_SCRIPT/, process.env.ANALYZE_SCRIPT)
        .replace(/PAYLOAD_XXXX_PAYLOAD/, Buffer.from(JSON.stringify(payload)).toString('base64'))

    console.log(JSON.stringify(process.env, null, 2))
    const client = new EC2Client({ region: payload.region })

    const cmd = new RunInstancesCommand({
        MinCount: 1, MaxCount: 1,

        InstanceInitiatedShutdownBehavior: 'terminate',
        TagSpecifications: [{
            ResourceType: 'instance',
            Tags: [
                { Key: 'Name', Value: `enclave-${input.analysis_id}` },
                { Key: 'Environment', Value: process.env.ENVIRONMENT },
                { Key: 'Project', Value: 'Research' },
                { Key: 'Application', Value: 'KineticWorkspaces' },
            ],
        }],
        IamInstanceProfile: {
            Arn: process.env.IAM_INSTANCE_ARN || '',
        },
        SecurityGroupIds: [process.env.SECURITY_GID || ''],
        InstanceType: 't3a.micro',
        SubnetId: process.env.SUBNET_ID,
        ImageId: process.env.IMAGE_ID,
        KeyName: process.env.KEY_NAME,
        UserData: Buffer.from(script).toString('base64'),
    })

    //        return '1234 done'
    try {

        const response = await client.send(cmd)

        console.log(response)

        return JSON.stringify({ instance_id: response.Instances?.[0].InstanceId })
    } catch (err) {
        console.log(err)

    }

};
