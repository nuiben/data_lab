import {
  SFNClient,
  ListExecutionsCommand,
  StartExecutionCommand,
} from "@aws-sdk/client-sfn";
import { NextResponse } from "next/server";

const sfn = new SFNClient({ region: process.env.AWS_REGION ?? "us-east-1" });
const ARN = process.env.SFN_STATE_MACHINE_ARN ?? "";

export async function GET() {
  if (!ARN) return NextResponse.json([]);
  try {
    const resp = await sfn.send(
      new ListExecutionsCommand({ stateMachineArn: ARN, maxResults: 20 })
    );
    return NextResponse.json(resp.executions ?? []);
  } catch {
    return NextResponse.json([]);
  }
}

export async function POST() {
  if (!ARN) {
    return NextResponse.json({ error: "SFN_STATE_MACHINE_ARN not configured" }, { status: 503 });
  }
  const name = `ui-run-${Date.now()}`;
  const resp = await sfn.send(
    new StartExecutionCommand({ stateMachineArn: ARN, name, input: "{}" })
  );
  return NextResponse.json({ executionArn: resp.executionArn, name });
}
