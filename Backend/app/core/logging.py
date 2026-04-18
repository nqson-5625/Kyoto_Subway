import logging # ghi log, debug, theo dõi hệ thống

def setup_logging() -> None:
    logging.basicConfig(
        level=logging.INFO, # Mức log hiển thị (mức INFO)
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s"
    )