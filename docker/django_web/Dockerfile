FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    procps \
    && rm -rf /var/lib/apt/lists/*

ARG USER_ID=1000
ARG GROUP_ID=1000

RUN groupadd -g ${GROUP_ID} appuser && \
    useradd -m -u ${USER_ID} -g appuser appuser

WORKDIR /app

ARG REQUIREMENTS_FILE=./django_project_folder/requirements.txt
COPY ${REQUIREMENTS_FILE} /tmp/requirements.txt
RUN pip install --upgrade pip && \
    pip install -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

COPY ./docker/django_web/stop_django.sh /usr/local/bin/stop_django
COPY ./docker/django_web/start_django.sh /usr/local/bin/start_django
COPY ./docker/django_web/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/stop_django /usr/local/bin/start_django /usr/local/bin/entrypoint.sh

RUN chown -R appuser:appuser /app

USER appuser

# Project files are bind-mounted at runtime for development
EXPOSE 8000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
