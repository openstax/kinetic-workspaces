import { EC2Client, RunInstancesCommand } from "@aws-sdk/client-ec2";

import { Handler } from 'aws-lambda'

import type { EventInput } from './types'

// @ts-ignore
import userDataTemplate from './ec2-user-data.sh'

type Event = {
    input: EventInput
    script: string
    token: string
}

export const handler: Handler<Event> = async ({ input, token, script }) => {

    const payload: EventInput = {
        ...input,
        region: process.env.AWS_REGION || 'us-east-1',
        base_image: process.env.BASE_IMAGE || '',
        task_token: token,
    }

    const userData = userDataTemplate
        .replace(/SCRIPT_XXXX_SCRIPT/, script)
        .replace(/PAYLOAD_XXXX_PAYLOAD/, Buffer.from(JSON.stringify(payload)).toString('base64'))

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
        UserData: Buffer.from(userData).toString('base64'),
    })

    try {
        const response = await client.send(cmd)
        return JSON.stringify({ instance_id: response.Instances?.[0].InstanceId })
    } catch (err) {
        console.log(err)
    }

};
