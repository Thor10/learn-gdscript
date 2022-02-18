import os
from babel.messages import extract
from babel.messages import Catalog
from babel.messages import pofile

PROJECT = "Learn GDScript From Zero"
VERSION = " "
COPYRIGHT_HOLDER = "GDQuest"
BUGS_ADDRESS = "https://github.com/GDQuest/learn-gdscript"


def extract_application_messages() -> None:
	print("Reading application messages...")

	globs_map = [
		('ui/**/**.gd', 'python'),
		('ui/**/**.tscn', 'godot_scene'),
	]
	options_map = {
		'ui/**/**.gd': {
			'encoding': 'utf-8'
		},
		'ui/**/**.tscn': {
			'encoding': 'utf-8'
		},
	}

	keywords = {
		# Properties stored in scenes.
		"Label/text": None,
		"Button/text": None,
		"RichTextLabel/bbcode_text": None,
		"LineEdit/placeholder_text": None,

		# Code-based translated strings
		"tr": None,
	}

	extract_and_write(
		globs_map=globs_map,
		options_map=options_map,
		keywords=keywords,
		output_file="./i18n/application.pot",
	)



def extract_course_messages() -> None:
	lessons_directory = "./course"
	for filename in os.listdir(lessons_directory):
		full_path = os.path.join(lessons_directory, filename)
		if filename.startswith("lesson-") and os.path.isdir(full_path):
			extract_lesson_messages(lesson=filename)


def extract_lesson_messages(lesson: str) -> None:
	print("Reading lesson messages from '" + 'course/' + lesson + '/lesson.tres' + "'...")

	globs_map = [
		('course/' + lesson + '/lesson.tres', 'godot_resource'),
	]
	options_map = {
		'course/' + lesson + '/lesson.tres': {
			'encoding': 'utf-8'
		},
	}

	keywords = {
		# Content blocks.
		"Resource/title": None,
		"Resource/text": None,

		# Quizzes.
		"Resource/question": None,
		"Resource/hint": None,
		"Resource/content_bbcode": None,
		"Resource/explanation_bbcode": None,
		"Resource/valid_answer": None,
		"Resource/answer_options": None,
		"Resource/valid_answers": None,

		# Practices.
		"Resource/goal": None,
		"Resource/description": None,
		"Resource/hints": None,
	}

	extract_and_write(
		globs_map=globs_map,
		options_map=options_map,
		keywords=keywords,
		output_file="./i18n/" + lesson + ".pot",
	)


def extract_and_write(
	globs_map,
	options_map,
	keywords,
	output_file: str,
) -> None:

	print("  Starting extraction...")
	extractor = extract.extract_from_dir(
		dirname=".",
		method_map=globs_map,
		options_map=options_map,
		keywords=keywords,
		comment_tags=(),
		callback=_log_extraction_file,
		strip_comment_tags=False
	)

	cat = Catalog(
		project=PROJECT,
		version=VERSION,
		copyright_holder=COPYRIGHT_HOLDER,
		msgid_bugs_address=BUGS_ADDRESS
	)

	# (filename, lineno, message, comments, context)
	for message in extractor:
		message_id = message[2]
		message_id = message_id.replace("\r\n", "\n")

		cat.add(
			id=message_id,
			string="",
			locations=[(message[0], message[1])],
			auto_comments=message[3],
			context=message[4],
		)

	with open(output_file, "wb") as file:
		pofile.write_po(
			fileobj=file,
			catalog=cat,
		)

	print("  Finished extraction.")


def _log_extraction_file(filename, method, options):
	print("  Extracting from file '" + filename + "'")


def main():
	extract_application_messages()
	extract_course_messages()


if __name__ == "__main__":
	main()