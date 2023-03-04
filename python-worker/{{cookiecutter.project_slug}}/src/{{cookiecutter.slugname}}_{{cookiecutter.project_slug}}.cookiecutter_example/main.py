from os import getenv
import logging

import redis
from httpx import AsyncClient
from arq.connections import RedisSettings

logger = logging.getLogger(name="{{ cookiecutter.project_slug }}")
logger.setLevel(logging.DEBUG)
logger.debug("hi")

NGINX_HOST = getenv("NGINX_HOST")
SERVER_PORT = int(getenv("SERVER_PORT"))
port_str = f":{SERVER_PORT}" if SERVER_PORT not in (443, 80) else ""
server_url = f"http://{NGINX_HOST}{port_str}"

r_kwargs = redis.connection.parse_url(getenv("REDIS_URL_DEFAULT_USER"))
if r_kwargs.get("connection_path") == redis.connection.UnixDomainSocketConnection:
    r_kwargs["unix_socket_path"] = r_kwargs["path"]
if r_kwargs.get("db") is not None:
    r_kwargs["database"] = r_kwargs.get("db", 0)
    del r_kwargs["db"]
redis_settings = RedisSettings(**r_kwargs)


async def startup(ctx):
    ctx["session"] = AsyncClient(base_url=server_url)


async def shutdown(ctx):
    await ctx["session"].aclose()


async def job_start(ctx):
    logger.info(f"job start {ctx}")
    print("start")


async def get_internal_path(ctx, path, params=None, headers={}):
    session = ctx["session"]
    logger.info(f"get_internal_path {path} {params} {headers}")
    response = await session.get(path, params=params, headers=headers)
    result = f"{response.status_code} {response.reason_phrase} {response.text}"
    logger.info(result)
    return result


async def post_internal_path(ctx, path, params=None, headers={}):
    session = ctx["session"]
    logger.info(f"post_internal_path {path} {params} {headers}")
    response = await session.post(path, params=params, headers=headers)
    result = f"{response.status_code} {response.reason_phrase} {response.text}"
    logger.info(result)
    return result


class WorkerSettings:
    redis_settings = redis_settings
    functions = [get_internal_path, post_internal_path]
    on_startup = startup
    on_shutdown = shutdown
    on_job_start = job_start
