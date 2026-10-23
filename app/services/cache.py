import redis

from app.config import settings

redis_client = redis.Redis.from_url(
    settings.redis_url,
    decode_responses=True,
    socket_connect_timeout=1,
)

def get_cached_url(short_code:str)->str|None:
    try:
        return redis_client.get(f"url:{short_code}")
    except redis.RedisError:
        return None
    
def cache_url(short_code:str,long_url:str,ttl=300):
    try:
        redis_client.set(
            f"url:{short_code}",
            long_url,
            ex=ttl
        )
    except redis.RedisError:
        pass
        