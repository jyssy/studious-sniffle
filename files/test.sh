
#!/bin/bash

# Set variables
TIMESTAMP=$(date +"%Y%m%d%H%M%S") # Generates a timestamp in the format YYYYMMDDHHMMSS
FILE_NAME="random_data_$TIMESTAMP.bin" # Name of the file to be created with timestamp
S3_BUCKET="s3://drb-ao-backup-test" # Replace with your S3 bucket name

# Step 1: Generate a file with 128 bytes of random data
echo "Generating random data file..."
head -c 128 /dev/urandom > $FILE_NAME

# Step 2: Upload the file to the S3 bucket
echo "Uploading file to S3..."
aws s3 cp $FILE_NAME $S3_BUCKET/

if [ $? -eq 0 ]; then
    echo "File successfully uploaded to S3 bucket: $S3_BUCKET"
else
    echo "Failed to upload file to S3. Please check your AWS credentials and permissions."
fi

# Optional: Clean up the file after uploading
rm $FILE_NAME
