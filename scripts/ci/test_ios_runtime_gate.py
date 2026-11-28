import subprocess
import unittest
from unittest.mock import patch
from ios_runtime_gate import create_fresh_device, prepare_device, select_device, verify_summary


class RuntimeGateTests(unittest.TestCase):
    def test_selects_available_booted_phone_over_unavailable_or_ipad(self):
        phone = {'name':'iPhone 17', 'udid':'ready', 'isAvailable':True, 'state':'Booted'}
        inventory = {'devices':{'runtime':[{'name':'iPhone 17', 'udid':'bad','isAvailable':False},
            {'name':'iPad Pro','udid':'ipad','isAvailable':True,'state':'Booted'}, phone]}}
        self.assertEqual(select_device(inventory), phone)

    def test_missing_phone_fails_instead_of_skipping(self):
        with self.assertRaises(ValueError): select_device({'devices':{}})

    def test_fresh_device_preserves_runtime_and_type_without_erasing_existing(self):
        phone = {'name':'iPhone 17', 'udid':'existing', 'state':'Booted',
                 'deviceTypeIdentifier':'com.apple.CoreSimulator.SimDeviceType.iPhone-17'}
        runtime = 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'
        identifier = '11111111-2222-4333-8444-555555555555'
        with patch('ios_runtime_gate.subprocess.check_output', return_value=identifier+'\n') as run:
            fresh = create_fresh_device({'devices':{runtime:[phone]}}, phone)
        command = run.call_args.args[0]
        self.assertEqual(command[:3], ['xcrun', 'simctl', 'create'])
        self.assertTrue(command[3].startswith('HiAir-CI-'))
        self.assertEqual(command[4:], [phone['deviceTypeIdentifier'], runtime])
        self.assertEqual(run.call_count, 1)
        self.assertEqual(fresh['udid'], identifier)
        self.assertEqual(fresh['state'], 'Shutdown')
        self.assertEqual(phone['udid'], 'existing')
        self.assertEqual(phone['state'], 'Booted')

    def test_fresh_device_missing_metadata_fails_without_command(self):
        with patch('ios_runtime_gate.subprocess.check_output') as run:
            with self.assertRaises(ValueError):
                create_fresh_device({'devices':{}}, {'udid':'existing'})
            with self.assertRaises(ValueError):
                create_fresh_device({'devices':{'runtime':[{'udid':'existing'}]}}, {'udid':'existing'})
        run.assert_not_called()

    def test_fresh_device_invalid_identifier_does_not_fall_back(self):
        phone = {'udid':'existing', 'deviceTypeIdentifier':'type'}
        with patch('ios_runtime_gate.subprocess.check_output', return_value='not-a-device'):
            with self.assertRaises(ValueError):
                create_fresh_device({'devices':{'runtime':[phone]}}, phone)

    def test_prepare_retries_once_after_bootstatus_timeout(self):
        phone = {'name':'iPhone 17', 'udid':'existing', 'state':'Shutdown', 'isAvailable':True,
                 'deviceTypeIdentifier':'com.apple.CoreSimulator.SimDeviceType.iPhone-17'}
        runtime = 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'
        inventory = {'devices':{runtime:[phone]}}
        first = '11111111-2222-4333-8444-555555555555'
        second = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
        timeout = subprocess.TimeoutExpired(['xcrun', 'simctl', 'bootstatus', first, '-b'], 300)

        def create_side_effect(command, **_kwargs):
            if command[:3] == ['xcrun', 'simctl', 'create']:
                create_side_effect.n += 1
                return (first if create_side_effect.n == 1 else second) + '\n'
            raise AssertionError(command)
        create_side_effect.n = 0

        def run_side_effect(command, **_kwargs):
            if command[:3] == ['xcrun', 'simctl', 'boot']:
                return subprocess.CompletedProcess(command, 0)
            if command[:3] == ['xcrun', 'simctl', 'bootstatus']:
                if command[3] == first:
                    raise timeout
                return subprocess.CompletedProcess(command, 0)
            if command[:3] == ['xcrun', 'simctl', 'list']:
                return subprocess.CompletedProcess(command, 0)
            if command[:3] == ['xcrun', 'simctl', 'shutdown']:
                return subprocess.CompletedProcess(command, 0)
            if command[:3] == ['xcrun', 'simctl', 'delete']:
                return subprocess.CompletedProcess(command, 0)
            raise AssertionError(command)

        with patch('ios_runtime_gate.subprocess.check_output', side_effect=create_side_effect), \
             patch('ios_runtime_gate.subprocess.run', side_effect=run_side_effect) as run:
            device = prepare_device(inventory, fresh=True, boot_attempts=2)
        self.assertEqual(device['udid'], second)
        self.assertEqual(device['state'], 'Booted')
        delete_calls = [c.args[0] for c in run.call_args_list if c.args[0][:3] == ['xcrun', 'simctl', 'delete']]
        self.assertEqual(delete_calls, [['xcrun', 'simctl', 'delete', first]])

    def test_prepare_exhausted_retries_still_fail(self):
        phone = {'name':'iPhone 17', 'udid':'existing', 'state':'Shutdown', 'isAvailable':True,
                 'deviceTypeIdentifier':'com.apple.CoreSimulator.SimDeviceType.iPhone-17'}
        runtime = 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'
        inventory = {'devices':{runtime:[phone]}}
        udids = ['11111111-2222-4333-8444-555555555555', 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee']

        def create_output(command, **_kwargs):
            if command[:3] == ['xcrun', 'simctl', 'create']:
                value = udids[create_output.n]
                create_output.n += 1
                return value + '\n'
            raise AssertionError(command)
        create_output.n = 0

        def run_side_effect(command, **_kwargs):
            if command[:3] in (['xcrun', 'simctl', 'boot'], ['xcrun', 'simctl', 'list'],
                               ['xcrun', 'simctl', 'shutdown'], ['xcrun', 'simctl', 'delete']):
                return subprocess.CompletedProcess(command, 0)
            if command[:3] == ['xcrun', 'simctl', 'bootstatus']:
                raise subprocess.TimeoutExpired(command, 300)
            raise AssertionError(command)

        with patch('ios_runtime_gate.subprocess.check_output', side_effect=create_output), \
             patch('ios_runtime_gate.subprocess.run', side_effect=run_side_effect):
            with self.assertRaises(subprocess.TimeoutExpired):
                prepare_device(inventory, fresh=True, boot_attempts=2)

    def test_missing_skipped_or_failed_run_cannot_certify(self):
        for value in ({}, {'totalTestCount':0,'passedTests':0,'failedTests':0,'skippedTests':0},
            {'totalTestCount':244,'passedTests':243,'failedTests':0,'skippedTests':1},
            {'totalTestCount':244,'passedTests':243,'failedTests':1,'skippedTests':0}):
            with self.subTest(value=value), self.assertRaises(ValueError): verify_summary(value)

    def test_executed_complete_run_certifies(self):
        self.assertEqual(verify_summary({'totalTestCount':244,'passedTests':244,'failedTests':0,'skippedTests':0}),244)


if __name__ == '__main__': unittest.main()
