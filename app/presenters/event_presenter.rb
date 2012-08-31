class EventPresenter < Presenter
  def to_hash
    basic_hash.
      merge(targets_hash).
      merge(additional_data_hash).
      merge(note_action_type_hash).
      merge(note_attachment_hash)
  end

  private

  def basic_hash
    {
      :id => model.id,
      :actor => present(model.actor),
      :action => action,
      :timestamp => model.created_at
    }
  end

  def action
    return "NOTE" if model.is_a?(Events::Note)

    model.action
  end

  def note_action_type_hash
    return { :action_type => model.action } if model.is_a?(Events::Note)
    {}
  end

  def additional_data_hash
    pairs = model.additional_data.map do |key, value|
      if value.class == String
        [key, sanitize(value)]
      else
        [model.additional_data_key(key), present(model.additional_data_value(key))]
      end

    end
    Hash[pairs]
  end

  def targets_hash
    model.targets.reduce({}) do |hash, entry|
      name, model = entry
      hash[name] = present(model, @options)
      hash
    end
  end

  def note_attachment_hash
    hash = []
    if model.is_a?(Events::Note)
      attachments = model.attachments
      attachments.each_with_index do |model, index|
        hash[index] = present(model)
      end
      datasets = model.datasets
      datasets.each do |dataset|
        model_hash = present(dataset, {:workspace => model.workspace}.merge(@options))
        model_hash.merge!({:workspace => model.workspace}) if model.workspace
        model_hash.merge!({:entity_type => 'dataset'} )
        hash << model_hash
        end
      workfiles = model.workfiles
      workfiles.each do |workfile|
        model_hash = present(workfile.latest_workfile_version)
        model_hash.merge!({:entity_type => 'workfile'} )
        hash << model_hash
      end
    end
    return {:attachments => hash}
  end
end
