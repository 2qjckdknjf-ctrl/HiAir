import unittest
from ios_runtime_gate import select_device, verify_summary


class RuntimeGateTests(unittest.TestCase):
    def test_selects_available_booted_phone_over_unavailable_or_ipad(self):
        phone = {'name':'iPhone 17', 'udid':'ready', 'isAvailable':True, 'state':'Booted'}
        inventory = {'devices':{'runtime':[{'name':'iPhone 17', 'udid':'bad','isAvailable':False},
            {'name':'iPad Pro','udid':'ipad','isAvailable':True,'state':'Booted'}, phone]}}
        self.assertEqual(select_device(inventory), phone)

    def test_missing_phone_fails_instead_of_skipping(self):
        with self.assertRaises(ValueError): select_device({'devices':{}})

    def test_missing_skipped_or_failed_run_cannot_certify(self):
        for value in ({}, {'totalTestCount':0,'passedTests':0,'failedTests':0,'skippedTests':0},
            {'totalTestCount':244,'passedTests':243,'failedTests':0,'skippedTests':1},
            {'totalTestCount':244,'passedTests':243,'failedTests':1,'skippedTests':0}):
            with self.subTest(value=value), self.assertRaises(ValueError): verify_summary(value)

    def test_executed_complete_run_certifies(self):
        self.assertEqual(verify_summary({'totalTestCount':244,'passedTests':244,'failedTests':0,'skippedTests':0}),244)


if __name__ == '__main__': unittest.main()
