from flask import Flask
from dotenv import load_dotenv
import os
import logging

from backend.animals.animal_routes import animals
from backend.adopters.adopter_routes import adopters
from backend.admin.admin_routes import admin
from backend.analytics.analytics_routes import analytics
from backend.stories.story_routes import success_stories
from backend.db_connection import init_app as init_db
from backend.simple.simple_routes import simple_routes
from backend.ngos.ngo_routes import ngos


def create_app():
    app = Flask(__name__)

    app.logger.setLevel(logging.DEBUG)
    app.logger.info('API startup')

    # Load environment variables from the .env file so they are
    # accessible via os.getenv() below.
    load_dotenv()

    # Secret key used by Flask for securely signing session cookies.
    app.config["SECRET_KEY"] = os.getenv("SECRET_KEY")

    # Database connection settings — values come from the .env file.
    app.config["MYSQL_DATABASE_USER"] = os.getenv("DB_USER").strip()
    app.config["MYSQL_DATABASE_PASSWORD"] = os.getenv("MYSQL_ROOT_PASSWORD").strip()
    app.config["MYSQL_DATABASE_HOST"] = os.getenv("DB_HOST").strip()
    app.config["MYSQL_DATABASE_PORT"] = int(os.getenv("DB_PORT").strip())
    app.config["MYSQL_DATABASE_DB"] = os.getenv("DB_NAME").strip()

    # Register the cleanup hook for the database connection.
    app.logger.info("create_app(): initializing database connection")
    init_db(app)

    # Register the routes from each Blueprint with the app object
    # and give a url prefix to each.
    app.logger.info("create_app(): registering blueprints")
    app.register_blueprint(simple_routes)
    app.register_blueprint(ngos, url_prefix="/ngo")
    app.register_blueprint(animals, url_prefix="/animals")
    app.register_blueprint(adopters, url_prefix="/adopters")
    app.register_blueprint(admin, url_prefix="/admin")
    app.register_blueprint(analytics, url_prefix="/analytics")
    app.register_blueprint(success_stories, url_prefix="/success_story")

    return app
