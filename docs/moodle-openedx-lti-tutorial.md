# Moodle using Open edX through LTI

## Recommended roles

Use Moodle as the learner entry point. Use Open edX Studio to author reusable courseware. Add selected Open edX units/components into Moodle as External Tool activities.

## Step 1: Create Open edX content

1. Open Studio: `http://studio.192.168.3.205.sslip.io`
2. Create a course.
3. Add the content you want to expose: a subsection, a unit, or an individual component.
4. Publish the content.

Open edX can expose subsections, units, or components through LTI. Sections are not supported.

## Step 2: Create Moodle as an LTI consumer in Open edX

1. Open the Open edX LMS admin: `http://openedx.192.168.3.205.sslip.io/admin`
2. Log in as the Open edX superuser.
3. Go to `LTI Provider` -> `LTI Consumers` -> `Add`.
4. Use:
   - Consumer name: `moodle`
   - Consumer key: generate or set a stable value, for example `moodle-private`
   - Consumer secret: generate a strong secret
   - Instance GUID: leave blank
5. Authentication choice:
   - Easiest: leave `Require user account` and `Use lti pii` unchecked. Learners launch smoothly and grade passback still maps to the Moodle learner.
   - Better identity mapping: enable `Use lti pii` and configure Moodle to share learner email.
   - Strict mapping: enable `Require user account` only if learners already have matching Open edX accounts and Moodle sends email.
6. Save and copy the Consumer Key and Consumer Secret.

## Step 3: Build the Open edX LTI launch URL

The URL format is:

```text
http://openedx.192.168.3.205.sslip.io/lti_provider/courses/{course_id}/{usage_id}
```

Find `course_id` from the course URL. It looks like:

```text
course-v1:ORG+COURSE+RUN
```

Find `usage_id`:

- For a component or unit, open the courseware page as staff and use `Staff Debug Info`.
- Component usage ID is the `location` value.
- Unit usage ID is the `parent` value.
- For a subsection, copy it from the courseware URL. It usually contains `type@sequential`.

## Step 4: Add Open edX as a Moodle External Tool

1. Open Moodle: `http://moodle.192.168.3.205.sslip.io:18081`
2. Go to `Site administration` -> `Plugins` -> `Activity modules` -> `External tool` -> `Manage tools`.
3. Choose `Configure a tool manually`.
4. Use:
   - Tool name: `Open edX`
   - Tool URL: the LTI launch URL from Step 3
   - LTI version: LTI 1.1
   - Consumer key: the Open edX consumer key
   - Shared secret: the Open edX consumer secret
   - Default launch container: `New window`
   - Share launcher's name: optional
   - Share launcher's email: enable if using Open edX `Use lti pii` or `Require user account`
   - Accept grades from the tool: enable if the Open edX content is graded
   - Configuration usage: show in activity chooser
5. Save.

## Step 5: Add the tool inside a Moodle course

1. Open a Moodle course.
2. Turn editing on.
3. Add an activity or resource.
4. Select the configured `Open edX` external tool.
5. Save and test as a learner.

## Grade passback

For best grade behavior, link directly to a graded Open edX problem component. Component scores are returned immediately. Unit/subsection links aggregate grades and may take around 15 minutes.

## HTTPS and iframe note

This deployment starts on HTTP for local/private testing. Moodle's LTI page warns that HTTPS is preferable and HTTP tools can show blank pages in some configurations. Keep `Default launch container` as `New window` during local testing.

For production, switch both systems to HTTPS and then iframe embedding can be considered.
