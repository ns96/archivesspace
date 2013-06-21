ASpaceImport::Importer.importer :accessions do

  require_relative '../lib/csv_importer'
  include ASpaceImport::CSVImport


  def self.profile
    "Import Accession Records from a CSV file"
  end


  def self.configure
    {
      # 1. Map the cell data to schemas / handlers
      # {column header} => {data address}
      # or,
      # {column header} => [{filter method}, {data address}]

      'accession_title' => 'accession.title',
      'accession_number_1' => 'accession.id_0',
      'accession_number_2' => 'accession.id_1',
      'accession_number_3' => 'accession.id_2',
      'accession_number_4' => 'accession.id_3',
      'accession_accession_date' => [date_flip, 'accession.accession_date'],
      'accession_access_restrictions' => 'accession.access_restrictions',
      'accession_access_restrictions_note' => 'accession.access_restrictions_note',
      'accession_acquisition_type' => 'accession.acquisition_type',
      'accession_condition_description' => 'accession.condition_description',
      'accession_content_description' => 'accession.content_description',
      'accession_disposition' => 'accession.disposition',
      'accession_general_note' => 'accession.general_note',
      'accession_inventory' => 'accession.inventory',
      'accession_provenance' => 'accession.provenance',
      'accession_publish' => 'accession.publish',
      'accession_resource_type' => 'accession.resource_type',
      'accession_restrictions_apply' => 'accession.restrictions_apply',
      'accession_retention_rule' => 'accession.retention_rule',
      'accession_use_restrictions' => 'accession.use_restrictions',
      'accession_use_restrictions_note' => 'accession.use_restrictions_note',

      'date_1_label' => 'date_1.label',
      'date_1_expression' => 'date_1.expression',
      'date_1_begin' => 'date_1.begin',
      'date_1_end' => 'date_1.end',
      'date_1_type' => 'date_1.date_type',

      'date_2_label' => 'date_2.label',
      'date_2_expression' => 'date_2.expression',
      'date_2_begin' => 'date_2.begin',
      'date_2_end' => 'date_2.end',
      'date_2_type' => 'date_2.date_type',

      'extent_type' => 'extent.extent_type',
      'extent_container_summary' => 'extent.container_summary',
      'extent_number' => 'extent.number',

      'accession_acknowledgement_sent' => [normalize_boolean, 'acknowledgement_sent_event_date.boolean'],
      'accession_acknowledgement_sent_date' => [date_flip, 'acknowledgement_sent_event_date.expression'],

      'accession_agreement_received' => [normalize_boolean, 'agreement_received_event_date.boolean'],
      'accession_agreement_received_date' => [date_flip, 'agreement_received_event_date.expression'],

      'accession_agreement_sent' => [normalize_boolean, 'agreement_sent_event_date.boolean'],
      'accession_agreement_sent_date' => [date_flip, 'agreement_sent_event_date.expression'],

      'accession_cataloged' => [normalize_boolean, 'cataloged_event_date.boolean'],
      'accession_cataloged_date' => [date_flip, 'cataloged_event_date.expression'],

      'accession_processed' => [normalize_boolean, 'processed_event_date.boolean'],
      'accession_processed_date' => [date_flip, 'processed_event_date.expression'],


      # 2. Define data handlers
      #    :record_type of the schema (if other than the handler key)
      #    :defaults - hash which maps property keys to default values if nothing shows up in the source date
      #    :on_row_complete - Proc to run whenever a row in the CSV table is complete
      #        param 1 is the set of objects generated by the row
      #        param 2 is an object in the row (of the type described in the handler)

      :acknowledgement_sent_event_date => event_template('acknowledgement_sent'),

      :agreement_received_event_date => event_template('agreement_received'),

      :agreement_sent_event_date => event_template('agreement_sent'),

      :cataloged_event_date => event_template('cataloged'),

      :processed_event_date => event_template('processed'),

      :accession => {
        :defaults => accession_defaults,
        :on_row_complete => Proc.new { |queue, accession|
          queue.select {|obj| obj.class.record_type == 'event'}.each do |event|
            event.linked_records << {'role' => 'source', 'ref' => accession.uri}
          end
        }
      },

      :date_1 => {
        :record_type => :date,
        :defaults => date_defaults,
        :on_row_complete => Proc.new { |queue, date|
          queue.select {|obj| obj.class.record_type == 'accession'}.each do |accession|
            accession.dates << date
          end
        }


      },

      :date_2 => {
        :record_type => :date,
        :defaults => date_defaults,
        :on_row_complete => Proc.new { |queue, date|
          queue.select {|obj| obj.class.record_type == 'accession'}.each do |accession|
            accession.dates << date
          end
        }
      },

      :extent => {
        :defaults => {:portion => 'whole'},
        :on_row_complete => Proc.new { |queue, extent|
          queue.select {|obj| obj.class.record_type == 'accession'}.each do |accession|
            accession.extents << extent
          end
        }
      },

      :acknowledgement_sent_event_date => event_template('acknowledgement_sent'),
      :cataloging_event_date => event_template('cataloging'),
      :agreement_sent_event_date => event_template('agreement_sent'),
      :processed_event_date => event_template('processed'),

    }

  end


  private

  def self.event_template(event_type)
    {
      :record_type => Proc.new {|data|
        data['boolean'] ? :date : nil
      },
      :defaults => date_defaults,
      :on_create => Proc.new {|data, obj|
        obj.expression = 'unknown' unless data['expression']
      },
      :on_row_complete => Proc.new { |queue, date|
        accession = queue.find {|obj| obj.class.record_type == 'accession'}
        event = ASpaceImport::JSONModel(:event).new
        queue << event
        event.event_type = event_type
        # Not sure how best to handle this, assuming for now that the built-in ASpace agent exists:
        event.linked_agents << {'role' => 'executing_program', 'ref' => '/agents/software/1'}
        event.date = date
        event.linked_records << {'role' => 'subject', 'ref' => accession.uri}
      }
    }
  end


  def self.accession_defaults
    {
      :condition_description => "'Condition Description', as required",
      :content_description => "'Content Description', as required",
    }
  end


  def self.date_defaults
    {
      :label => 'other',
      :date_type => 'inclusive'
    }
  end


  def self.date_flip

    @date_flip ||= Proc.new {|val| val.sub(/^([0-9]{1,2})\/([0-9]{1,2})\/([0-9]{4})$/, '\2/\1/\3')}

    @date_flip
  end


  def self.normalize_boolean
    @normalize_boolean ||= Proc.new {|val| val.to_s.upcase.match(/\A(1|T|Y|YES|TRUE)\Z/) ? true : false }
    @normalize_boolean
  end
end




