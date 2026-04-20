from flask import Blueprint, request, jsonify
from backend.db_connection import get_db

success_stories = Blueprint('success_stories', __name__)


@success_stories.route('/', methods=['GET'])
def get_stories():
    page = int(request.args.get('page', 1))
    per_page = int(request.args.get('per_page', 5))
    offset = (page - 1) * per_page

    sort = request.args.get('sort', 'newest')
    rating_min = request.args.get('rating_min', 1)
    rating_max = request.args.get('rating_max', 10)

    sort_clause = {
        'newest': 'posted_at DESC',
        'oldest': 'posted_at ASC',
        'rating': 'rating DESC'
    }.get(sort, 'posted_at DESC')

    query = f"""
        SELECT story_id, rating, content, posted_at
        FROM success_story
        WHERE is_reviewed = TRUE
          AND rating BETWEEN %s AND %s
        ORDER BY {sort_clause}
        LIMIT %s OFFSET %s
    """

    count_query = """
        SELECT COUNT(*) as total
        FROM success_story
        WHERE is_reviewed = TRUE
          AND rating BETWEEN %s AND %s
    """

    cursor = get_db().cursor(dictionary=True)
    cursor.execute(query, (rating_min, rating_max, per_page, offset))
    rows = cursor.fetchall()

    cursor.execute(count_query, (rating_min, rating_max))
    total = cursor.fetchone()['total']
    total_pages = max(1, -(-total // per_page))

    return jsonify({
        "stories": rows,
        "total_pages": total_pages
    })
