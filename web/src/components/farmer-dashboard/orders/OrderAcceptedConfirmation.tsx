import React from 'react'
import { CheckCircle } from 'lucide-react'

interface OrderAcceptedConfirmationProps {
  onBackToOrders: () => void
  onGoToDashboard: () => void
}

const OrderAcceptedConfirmation: React.FC<OrderAcceptedConfirmationProps> = ({ onBackToOrders, onGoToDashboard }) => {
  return (
    <div className="min-h-screen bg-white flex items-center justify-center p-6">
      <div className="max-w-md w-full text-center space-y-6">
        <div className="w-32 h-32 rounded-full bg-green-100 flex items-center justify-center mx-auto">
          <CheckCircle className="w-16 h-16 text-green-600" />
        </div>

        <h1 className="text-3xl font-bold text-gray-800">Order Accepted!</h1>
        <p className="text-base text-gray-600">The buyer has been notified about your acceptance.</p>

        <div className="bg-green-50 border border-green-200 rounded-xl p-4 text-left text-sm text-green-800">
          💚 Next Steps: The buyer will contact you shortly to arrange delivery and payment details.
        </div>

        <div className="flex flex-col gap-3">
          <button
            onClick={onBackToOrders}
            className="w-full py-4 rounded-xl bg-green-600 text-white hover:bg-green-700"
          >
            Back to My Orders
          </button>

          <button
            onClick={onGoToDashboard}
            className="w-full py-4 rounded-xl bg-white border border-green-600 text-green-600 hover:bg-green-50"
          >
            Go to Dashboard
          </button>
        </div>
      </div>
    </div>
  )
}

export default OrderAcceptedConfirmation
