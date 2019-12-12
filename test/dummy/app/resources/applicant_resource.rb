class ApplicantResource < BaseResource
  attributes :name,
             :nickname,
             :email

  def self.records(opts)
    results = super(opts)

    allow_stimpy = opts.dig(:context, :allow_stimpy)

    return results if allow_stimpy

    results.where('nickname IS NOT ?', '_stimpy_')
  end
end
