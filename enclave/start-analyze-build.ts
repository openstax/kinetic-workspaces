import {
    EC2Client, RunInstancesCommand,
    // RunInstancesCommandInput, DescribeInstancesCommand, Instance,
    // TerminateInstancesCommand,
} from '@aws-sdk/client-ec2'

import { Handler } from 'aws-lambda'

// @ts-ignore
import userData from './build-docker.rb'

type Event = {
    input:{
        archive_path: string
        analysis_id: number
    }
    token: string
}

export const handler: Handler<Event> = async ({ input, token }) => {

    console.log(
        JSON.stringify(input, null, 2),
        JSON.stringify(process.env, null, 2),
    )

    // return

    const client = new EC2Client({})

    const script = userData.replace(/TOKEN_XXXX_TOKEN/, token)

    const response = await client.send(new RunInstancesCommand({
        MinCount: 1, MaxCount: 1,

        InstanceInitiatedShutdownBehavior: 'terminate',
        TagSpecifications: [{
            ResourceType: 'instance',
            Tags: [
                { Key: 'Name', Value: `enclave-${input.analysis_id}` },
                { Key: 'Environment', Value: process.env.environment_name },
                { Key: 'Project', Value: 'Research' },
                { Key: 'Application', Value: 'KineticWorkspaces' },
            ],
        }],

        SecurityGroupIds: [process.env.SGID  || ''],
        InstanceType: 't3a.micro',
        SubnetId: process.env.SUBNET_ID,
        ImageId: process.env.IMAGE_ID,
        KeyName: process.env.KEY_NAME,
        UserData: Buffer.from(script).toString('base64'),
    }))

    return JSON.stringify({ instance_id: response.Instances?.[0].InstanceId })

};
