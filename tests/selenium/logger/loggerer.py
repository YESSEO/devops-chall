import logging
from logging import Logger
from datetime import datetime

class SimpleLogger:
    def __init__(self, logfile: str = "app.log", sample: str = "simple_example"):
        self.logger: Logger = logging.getLogger(sample)
        self.logger.setLevel(logging.DEBUG)

        fh = logging.FileHandler(logfile)
        fh.setLevel(logging.DEBUG)

        # Create formatter
        formatter = logging.Formatter(
            "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
        )
        fh.setFormatter(formatter)

        if not self.logger.handlers:  # avoid duplicate handlers
            self.logger.addHandler(fh)

    def write_log(self, level: str, message: str):
        level = level.upper()
        if level == "DEBUG":
            self.logger.debug(message)
        elif level == "INFO":
            self.logger.info(message)
        elif level == "WARNING":
            self.logger.warning(message)
        elif level == "ERROR":
            self.logger.error(message)
        elif level == "CRITICAL":
            self.logger.critical(message)
        else:
            self.logger.info(message)  # default to INFO

if __name__ == "__main__":
    log = SimpleLogger("example.log", "simple_example")
    log.write_log("DEBUG", "debug message")
    log.write_log("INFO", "info message")
    log.write_log("WARNING", "warn message")
    log.write_log("ERROR", "error message")
    log.write_log("CRITICAL", "critical message")
