class HardJob
  include Sidekiq::Job

  def perform(*args)
    Rails.logger.info("HardJob started")
    sleep 0.35
    Rails.logger.info("HardJob finished")
  end
end