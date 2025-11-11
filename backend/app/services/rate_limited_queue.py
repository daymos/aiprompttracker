import asyncio
from typing import Callable, Any
from collections import deque
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)


class RateLimitedQueue:
    """
    Rate-limited queue for API requests
    
    Ensures we maximize throughput while respecting API rate limits.
    All requests from all users share the same queue (since we have one API key).
    """
    
    def __init__(self, max_requests_per_minute: int = 50):
        """
        Initialize rate-limited queue
        
        Args:
            max_requests_per_minute: Maximum API requests allowed per minute
        """
        self.max_requests_per_minute = max_requests_per_minute
        self.request_timestamps = deque()  # Track request times
        self.lock = asyncio.Lock()  # Ensure thread-safe access
        
        logger.info(f"🚦 Initialized rate-limited queue: {max_requests_per_minute} requests/minute")
    
    async def execute(self, func: Callable, *args, **kwargs) -> Any:
        """
        Execute a function with rate limiting
        
        Args:
            func: Async function to execute
            *args: Positional arguments for func
            **kwargs: Keyword arguments for func
            
        Returns:
            Result from func
        """
        async with self.lock:
            # Clean up old timestamps (older than 1 minute)
            now = datetime.now()
            one_minute_ago = now - timedelta(minutes=1)
            
            while self.request_timestamps and self.request_timestamps[0] < one_minute_ago:
                self.request_timestamps.popleft()
            
            # Check if we need to wait
            if len(self.request_timestamps) >= self.max_requests_per_minute:
                # Calculate how long to wait
                oldest_request = self.request_timestamps[0]
                wait_until = oldest_request + timedelta(minutes=1)
                wait_seconds = (wait_until - now).total_seconds()
                
                if wait_seconds > 0:
                    logger.warning(f"⏳ Rate limit reached, waiting {wait_seconds:.1f}s")
                    await asyncio.sleep(wait_seconds)
                    
                    # Clean up again after waiting
                    now = datetime.now()
                    one_minute_ago = now - timedelta(minutes=1)
                    while self.request_timestamps and self.request_timestamps[0] < one_minute_ago:
                        self.request_timestamps.popleft()
            
            # Record this request
            self.request_timestamps.append(datetime.now())
            
            # Execute the function
            logger.debug(f"📤 Executing request ({len(self.request_timestamps)}/{self.max_requests_per_minute} in last minute)")
        
        # Execute outside the lock to allow other requests to queue up
        return await func(*args, **kwargs)
    
    def get_current_rate(self) -> int:
        """Get current number of requests in the last minute"""
        now = datetime.now()
        one_minute_ago = now - timedelta(minutes=1)
        
        # Clean up old timestamps
        while self.request_timestamps and self.request_timestamps[0] < one_minute_ago:
            self.request_timestamps.popleft()
        
        return len(self.request_timestamps)
    
    def get_available_capacity(self) -> int:
        """Get number of requests available before hitting rate limit"""
        return max(0, self.max_requests_per_minute - self.get_current_rate())


# Global singleton instance for RapidAPI
rapidapi_queue = RateLimitedQueue(max_requests_per_minute=50)

