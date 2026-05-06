import { S3Client, ListObjectsV2Command } from "@aws-sdk/client-s3";
import { NextResponse } from "next/server";

const s3 = new S3Client({ region: process.env.AWS_REGION ?? "us-east-1" });
const BUCKET = process.env.DATA_LAB_S3_BUCKET ?? "";

export async function GET() {
  if (!BUCKET) return NextResponse.json([]);
  try {
    const resp = await s3.send(
      new ListObjectsV2Command({ Bucket: BUCKET, Prefix: "fintech/", MaxKeys: 200 })
    );
    return NextResponse.json(resp.Contents ?? []);
  } catch {
    return NextResponse.json([]);
  }
}
