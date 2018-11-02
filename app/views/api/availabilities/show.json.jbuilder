json.id @availability.id
json.start_at @availability.start_at.iso8601
json.end_at @availability.end_at.iso8601
json.available_type @availability.available_type
json.machine_ids @availability.machine_ids
if availability.instance_of? Availability
  json.description availability.description
  json.username availability_username(@availability)
end
json.textColor availability_text_color(@availability)
json.backgroundColor availability_background_color(@availability)
json.borderColor availability_border_color(@availability)
json.title @availability.title
json.tag_ids @availability.tag_ids
json.tags @availability.tags do |t|
  json.id t.id
  json.name t.name
end
json.lock @availability.lock
