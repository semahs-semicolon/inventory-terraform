import * as AWS from "@aws-sdk/client-s3";
import sharp from 'sharp';

const s3 = new AWS.S3();

const targetBucket = process.env["TARGET_BUCKET"]


export const handler = async (event) => {
    for (const record of event.Records) {
        if (!record.eventName.includes("ObjectCreated")) return;

        const bucket = record.s3.bucket.name;
        const key = record.s3.object.key;
        const getParams = {
            Bucket: bucket,
            Key: key,
        };   
        const s3Object = await s3.getObject(getParams);
        const bytes = await s3Object.Body.transformToByteArray();


        const list = [
            doTransform(bytes, "thumbnail", key, (sharp) => sharp.rotate().resize(120,120,'inside')),
            doTransform(bytes, "objectview", key, (sharp) => sharp.rotate().resize(600,600,'inside')),
            doTransform(bytes, "webp", key, (sharp) => sharp.rotate())
        ];
        await Promise.all(list);
    }


  return { status: 200 }
}

export const doTransform = async (img, prefix, key, dothething) => {
    const processedImage = await dothething(sharp(img))
              .toFormat('webp', { quality: 80 })
              .toBuffer();


    const uploadParams = {
        Bucket: targetBucket,
        Key: prefix+"/"+key,
        ContentType: 'image/webp',
        Body: Buffer.from(processedImage, 'binary'),
    };
    await s3.putObject(uploadParams);
}