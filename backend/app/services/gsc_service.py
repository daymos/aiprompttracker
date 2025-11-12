"""Google Search Console API Service"""
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

logger = logging.getLogger(__name__)


class GSCService:
    """Service for interacting with Google Search Console API"""
    
    def __init__(self):
        self.service_name = "searchconsole"
        self.service_version = "v1"
    
    def _get_service(self, access_token: str, refresh_token: str = None):
        """Create a Search Console API service instance"""
        try:
            credentials = Credentials(
                token=access_token,
                refresh_token=refresh_token,
                token_uri="https://oauth2.googleapis.com/token",
                client_id=None,  # Not needed for API calls
                client_secret=None  # Not needed for API calls
            )
            
            service = build(
                self.service_name,
                self.service_version,
                credentials=credentials,
                cache_discovery=False
            )
            
            return service
        except Exception as e:
            logger.error(f"Error creating GSC service: {str(e)}")
            raise
    
    async def get_site_list(self, access_token: str, refresh_token: str = None) -> List[Dict[str, str]]:
        """Get list of GSC properties the user has access to"""
        try:
            service = self._get_service(access_token, refresh_token)
            
            # List all sites
            sites = service.sites().list().execute()
            
            site_list = []
            for site in sites.get('siteEntry', []):
                site_list.append({
                    'site_url': site.get('siteUrl'),
                    'permission_level': site.get('permissionLevel')
                })
            
            logger.info(f"Found {len(site_list)} GSC properties")
            return site_list
            
        except HttpError as e:
            logger.error(f"Error fetching GSC sites: {str(e)}")
            raise Exception(f"Failed to fetch GSC properties: {str(e)}")
        except Exception as e:
            logger.error(f"Unexpected error in get_site_list: {str(e)}")
            raise
    
    async def get_search_analytics(
        self,
        access_token: str,
        site_url: str,
        start_date: str = None,
        end_date: str = None,
        dimensions: List[str] = None,
        row_limit: int = 100,
        refresh_token: str = None
    ) -> Dict[str, Any]:
        """
        Get search analytics data from GSC
        
        Args:
            access_token: OAuth access token
            site_url: GSC property URL (e.g., 'sc-domain:example.com' or 'https://example.com/')
            start_date: Start date in YYYY-MM-DD format (default: 28 days ago)
            end_date: End date in YYYY-MM-DD format (default: 3 days ago - GSC data delay)
            dimensions: List of dimensions ['query', 'page', 'country', 'device', 'date']
            row_limit: Maximum number of rows to return
            refresh_token: Optional refresh token for token refresh
        
        Returns:
            Dict with performance data
        """
        try:
            service = self._get_service(access_token, refresh_token)
            
            # Default dates (GSC has ~3 day delay)
            if not end_date:
                end_date = (datetime.now() - timedelta(days=3)).strftime('%Y-%m-%d')
            if not start_date:
                start_date = (datetime.now() - timedelta(days=31)).strftime('%Y-%m-%d')
            
            # Default dimensions
            if not dimensions:
                dimensions = ['query']
            
            # Build request
            request = {
                'startDate': start_date,
                'endDate': end_date,
                'dimensions': dimensions,
                'rowLimit': row_limit
            }
            
            # Execute query
            response = service.searchanalytics().query(
                siteUrl=site_url,
                body=request
            ).execute()
            
            # Parse response
            rows = response.get('rows', [])
            
            # Calculate totals
            total_clicks = sum(row.get('clicks', 0) for row in rows)
            total_impressions = sum(row.get('impressions', 0) for row in rows)
            
            # Calculate weighted average CTR and position
            avg_ctr = (total_clicks / total_impressions * 100) if total_impressions > 0 else 0
            
            # Position is already averaged by GSC
            weighted_position_sum = sum(
                row.get('position', 0) * row.get('impressions', 0) 
                for row in rows
            )
            avg_position = (
                weighted_position_sum / total_impressions 
                if total_impressions > 0 
                else 0
            )
            
            # Also fetch daily data for chart visualization if date dimension requested
            daily_data = []
            if 'date' in dimensions:
                daily_data = []
                for row in rows:
                    date_key = row.get('keys', [''])[0] if row.get('keys') else None
                    if date_key:
                        daily_data.append({
                            'date': date_key,
                            'clicks': row.get('clicks', 0),
                            'impressions': row.get('impressions', 0),
                            'ctr': round(row.get('ctr', 0) * 100, 2),
                            'position': round(row.get('position', 0), 1)
                        })
            
            result = {
                'site_url': site_url,
                'start_date': start_date,
                'end_date': end_date,
                'total_clicks': total_clicks,
                'total_impressions': total_impressions,
                'average_ctr': round(avg_ctr, 2),
                'average_position': round(avg_position, 1),
                'rows': rows[:row_limit],  # Return detailed rows
                'daily_data': daily_data  # Daily breakdown for charts
            }
            
            logger.info(
                f"GSC Analytics: {total_impressions} impressions, "
                f"{total_clicks} clicks, {avg_ctr:.2f}% CTR, {len(daily_data)} daily points"
            )
            
            return result
            
        except HttpError as e:
            logger.error(f"Error fetching GSC analytics: {str(e)}")
            raise Exception(f"Failed to fetch GSC analytics: {str(e)}")
        except Exception as e:
            logger.error(f"Unexpected error in get_search_analytics: {str(e)}")
            raise
    
    async def get_top_queries(
        self,
        access_token: str,
        site_url: str,
        limit: int = 20,
        refresh_token: str = None
    ) -> List[Dict[str, Any]]:
        """Get top performing search queries"""
        try:
            data = await self.get_search_analytics(
                access_token=access_token,
                site_url=site_url,
                dimensions=['query'],
                row_limit=limit,
                refresh_token=refresh_token
            )
            
            # Format query data
            queries = []
            for row in data.get('rows', []):
                queries.append({
                    'query': row.get('keys', [''])[0],
                    'clicks': row.get('clicks', 0),
                    'impressions': row.get('impressions', 0),
                    'ctr': round(row.get('ctr', 0) * 100, 2),
                    'position': round(row.get('position', 0), 1)
                })
            
            return queries
            
        except Exception as e:
            logger.error(f"Error fetching top queries: {str(e)}")
            raise
    
    async def get_top_pages(
        self,
        access_token: str,
        site_url: str,
        limit: int = 20,
        refresh_token: str = None
    ) -> List[Dict[str, Any]]:
        """Get top performing pages"""
        try:
            data = await self.get_search_analytics(
                access_token=access_token,
                site_url=site_url,
                dimensions=['page'],
                row_limit=limit,
                refresh_token=refresh_token
            )
            
            # Format page data
            pages = []
            for row in data.get('rows', []):
                pages.append({
                    'page': row.get('keys', [''])[0],
                    'clicks': row.get('clicks', 0),
                    'impressions': row.get('impressions', 0),
                    'ctr': round(row.get('ctr', 0) * 100, 2),
                    'position': round(row.get('position', 0), 1)
                })
            
            return pages
            
        except Exception as e:
            logger.error(f"Error fetching top pages: {str(e)}")
            raise
    
    async def get_sitemaps(
        self,
        access_token: str,
        site_url: str,
        refresh_token: str = None
    ) -> List[Dict[str, Any]]:
        """Get sitemap information and status"""
        try:
            service = self._get_service(access_token, refresh_token)
            
            # List sitemaps
            sitemaps_response = service.sitemaps().list(
                siteUrl=site_url
            ).execute()
            
            sitemaps = []
            for sitemap in sitemaps_response.get('sitemap', []):
                sitemaps.append({
                    'path': sitemap.get('path'),
                    'last_submitted': sitemap.get('lastSubmitted'),
                    'last_downloaded': sitemap.get('lastDownloaded'),
                    'is_pending': sitemap.get('isPending', False),
                    'is_sitemaps_index': sitemap.get('isSitemapsIndex', False),
                    'warnings': sitemap.get('warnings', 0),
                    'errors': sitemap.get('errors', 0)
                })
            
            logger.info(f"Found {len(sitemaps)} sitemaps for {site_url}")
            return sitemaps
            
        except HttpError as e:
            logger.error(f"Error fetching sitemaps: {str(e)}")
            raise Exception(f"Failed to fetch sitemaps: {str(e)}")
        except Exception as e:
            logger.error(f"Unexpected error in get_sitemaps: {str(e)}")
            raise
    
    async def get_index_coverage(
        self,
        access_token: str,
        site_url: str,
        refresh_token: str = None
    ) -> Dict[str, Any]:
        """
        Get index coverage summary
        Note: This is a simplified version. Full URL inspection requires additional API calls.
        """
        try:
            # Get sitemaps as a proxy for indexing status
            sitemaps = await self.get_sitemaps(access_token, site_url, refresh_token)
            
            # Get recent performance data to estimate indexed pages
            data = await self.get_search_analytics(
                access_token=access_token,
                site_url=site_url,
                dimensions=['page'],
                row_limit=1000,
                refresh_token=refresh_token
            )
            
            pages_with_impressions = len(data.get('rows', []))
            
            return {
                'site_url': site_url,
                'sitemaps_count': len(sitemaps),
                'pages_with_impressions': pages_with_impressions,
                'sitemap_errors': sum(s.get('errors', 0) for s in sitemaps),
                'sitemap_warnings': sum(s.get('warnings', 0) for s in sitemaps),
                'sitemaps': sitemaps
            }
            
        except Exception as e:
            logger.error(f"Error fetching index coverage: {str(e)}")
            raise

