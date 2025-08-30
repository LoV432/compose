FROM python:3.9-slim

COPY src/ /src/
COPY cert/ /cert/

WORKDIR /

RUN pip install -r /src/requirements.txt
EXPOSE 443

CMD [ "python", "./src/main.py"]
