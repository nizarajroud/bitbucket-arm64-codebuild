FROM public.ecr.aws/docker/library/python:3.12-slim

LABEL architecture="arm64"
LABEL description="ARM64 demo image built via CodeBuild from Bitbucket Pipeline"

WORKDIR /app
COPY app.py .

CMD ["python3", "app.py"]
