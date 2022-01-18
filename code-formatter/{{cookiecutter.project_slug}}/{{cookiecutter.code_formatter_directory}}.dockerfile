FROM node:16-buster

# This {{ cookiecutter.code_formatter_directory }}.dockerfile should be at the top-level of the project.

RUN apt-get --yes update && apt-get --yes upgrade
RUN apt-get --yes install python3 \
  python3-dev \
  python3-pip \
  software-properties-common \
  gcc
RUN pip3 install black==21.10b0

WORKDIR /code

COPY {{ cookiecutter.code_formatter_directory }}/package.json ./
COPY {{ cookiecutter.code_formatter_directory }}/package-lock.json ./

RUN chown -R node:node /code
USER node

RUN node --version \
    && npm --version \
    && npm ci --ignore-scripts

COPY .editorconfig ./
COPY .flake8 ./
COPY .prettierrc ./
COPY .stylelintrc ./
COPY {{ cookiecutter.code_formatter_directory }}/format.sh ./

VOLUME /code/.last-modified

CMD ["npm", "run"]
