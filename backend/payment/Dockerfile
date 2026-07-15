FROM python:3.12-alpine

WORKDIR /app
COPY app.py /app/app.py

RUN addgroup -S app && adduser -S app -G app && mkdir /data && chown app:app /data

USER app
EXPOSE 8080
CMD ["python", "/app/app.py"]
