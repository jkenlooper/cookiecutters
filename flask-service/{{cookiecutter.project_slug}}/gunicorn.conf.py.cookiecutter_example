import sys
import subprocess
import logging

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s : %(msg)s")
logger = logging.getLogger(__file__)

logger.info("Loaded")


# https://docs.gunicorn.org/en/stable/settings.html#server-hooks
def on_starting(server):
    "Called just before the master process is initialized."
    logger.info(f"Starting {server.proc_name}")

    # Use flask cli to run a init-db command. This allows the service to do any
    # initialization work for a database before the service starts accepting
    # connections.
    try:
        subprocess.run(["flask", "init-db"], check=True)
    except subprocess.CalledProcessError as err:
        logger.exception(err)
        sys.exit(err.returncode if err.returncode > 0 else 1)
    logger.info("Finished run of 'flask init-db'")


def on_exit(server):
    "Called just before exiting Gunicorn."
    logger.info(f"Stopping {server.proc_name}")
