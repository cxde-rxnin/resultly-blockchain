#[test_only]
module blockchain::result_registry_tests {
    use blockchain::result_registry::{Self, ResultRegistry, AdminCap, InstitutionCap};
    use sui::test_scenario::{Self, Scenario};
    use sui::clock::{Self, Clock};
    use std::string;

    // Test addresses
    const ADMIN: address = @0xABCD;
    const INSTITUTION1: address = @0x1234;
    const INSTITUTION2: address = @0x5678;
    const STUDENT: address = @0x9999;

    fun init_test_scenario(): Scenario {
        test_scenario::begin(ADMIN)
    }

    #[test]
    fun test_init_and_authorize_institution() {
        let mut scenario = init_test_scenario();
        
        // Initialize the registry
        {
            result_registry::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, ADMIN);
        
        // Admin takes the AdminCap and authorizes an institution
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut registry = test_scenario::take_shared<ResultRegistry>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            
            result_registry::authorize_institution(
                &admin_cap,
                &mut registry,
                INSTITUTION1,
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            // Check if institution is authorized
            assert!(result_registry::is_institution_authorized(&registry, INSTITUTION1), 0);
            
            test_scenario::return_to_sender(&scenario, admin_cap);
            test_scenario::return_shared(registry);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun test_add_result() {
        let mut scenario = init_test_scenario();
        
        // Initialize and setup
        {
            result_registry::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, ADMIN);
        
        // Authorize institution
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut registry = test_scenario::take_shared<ResultRegistry>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            
            result_registry::authorize_institution(
                &admin_cap,
                &mut registry,
                INSTITUTION1,
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_to_sender(&scenario, admin_cap);
            test_scenario::return_shared(registry);
            clock::destroy_for_testing(clock);
        };

        test_scenario::next_tx(&mut scenario, INSTITUTION1);
        
        // Institution adds a result
        {
            let institution_cap = test_scenario::take_from_sender<InstitutionCap>(&scenario);
            let mut registry = test_scenario::take_shared<ResultRegistry>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            
            result_registry::add_result(
                &institution_cap,
                &mut registry,
                string::utf8(b"STU001"),
                string::utf8(b"CS101"),
                string::utf8(b"A"),
                string::utf8(b"Fall2024"),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            // Verify result exists
            assert!(result_registry::result_exists(
                &registry,
                string::utf8(b"STU001"),
                string::utf8(b"CS101"),
                string::utf8(b"Fall2024")
            ), 0);
            
            test_scenario::return_to_sender(&scenario, institution_cap);
            test_scenario::return_shared(registry);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun test_get_result() {
        let mut scenario = init_test_scenario();
        
        // Setup and add a result (similar to previous test)
        {
            result_registry::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, ADMIN);
        
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut registry = test_scenario::take_shared<ResultRegistry>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            
            result_registry::authorize_institution(
                &admin_cap,
                &mut registry,
                INSTITUTION1,
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_to_sender(&scenario, admin_cap);
            test_scenario::return_shared(registry);
            clock::destroy_for_testing(clock);
        };

        test_scenario::next_tx(&mut scenario, INSTITUTION1);
        
        {
            let institution_cap = test_scenario::take_from_sender<InstitutionCap>(&scenario);
            let mut registry = test_scenario::take_shared<ResultRegistry>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            
            result_registry::add_result(
                &institution_cap,
                &mut registry,
                string::utf8(b"STU001"),
                string::utf8(b"CS101"),
                string::utf8(b"A"),
                string::utf8(b"Fall2024"),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            // Get and verify the result
            let (student_id, course_code, grade, semester, _recorded_by, _created_at, _updated_at, verified) = 
                result_registry::get_result(
                    &registry,
                    string::utf8(b"STU001"),
                    string::utf8(b"CS101"),
                    string::utf8(b"Fall2024")
                );
            
            assert!(student_id == string::utf8(b"STU001"), 0);
            assert!(course_code == string::utf8(b"CS101"), 0);
            assert!(grade == string::utf8(b"A"), 0);
            assert!(semester == string::utf8(b"1st Semester"), 0);
            assert!(!verified, 0); // Should not be verified initially
            
            test_scenario::return_to_sender(&scenario, institution_cap);
            test_scenario::return_shared(registry);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun test_update_grade() {
        let mut scenario = init_test_scenario();
        
        // Setup and add initial result
        {
            result_registry::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, ADMIN);
        
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut registry = test_scenario::take_shared<ResultRegistry>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            
            result_registry::authorize_institution(
                &admin_cap,
                &mut registry,
                INSTITUTION1,
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_to_sender(&scenario, admin_cap);
            test_scenario::return_shared(registry);
            clock::destroy_for_testing(clock);
        };

        test_scenario::next_tx(&mut scenario, INSTITUTION1);
        
        {
            let institution_cap = test_scenario::take_from_sender<InstitutionCap>(&scenario);
            let mut registry = test_scenario::take_shared<ResultRegistry>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            
            // Add initial result
            result_registry::add_result(
                &institution_cap,
                &mut registry,
                string::utf8(b"STU001"),
                string::utf8(b"CS101"),
                string::utf8(b"B"),
                string::utf8(b"Fall2024"),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            // Update the grade
            result_registry::update_grade(
                &institution_cap,
                &mut registry,
                string::utf8(b"STU001"),
                string::utf8(b"CS101"),
                string::utf8(b"Fall2024"),
                string::utf8(b"A"),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            // Verify the grade was updated
            let (_, _, grade, _, _, _, _, _) = result_registry::get_result(
                &registry,
                string::utf8(b"STU001"),
                string::utf8(b"CS101"),
                string::utf8(b"Fall2024")
            );
            
            assert!(grade == string::utf8(b"A"), 0);
            
            test_scenario::return_to_sender(&scenario, institution_cap);
            test_scenario::return_shared(registry);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun test_verify_result() {
        let mut scenario = init_test_scenario();
        
        // Setup, add result, then verify it
        {
            result_registry::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, ADMIN);
        
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut registry = test_scenario::take_shared<ResultRegistry>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            
            result_registry::authorize_institution(
                &admin_cap,
                &mut registry,
                INSTITUTION1,
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_to_sender(&scenario, admin_cap);
            test_scenario::return_shared(registry);
            clock::destroy_for_testing(clock);
        };

        test_scenario::next_tx(&mut scenario, INSTITUTION1);
        
        {
            let institution_cap = test_scenario::take_from_sender<InstitutionCap>(&scenario);
            let mut registry = test_scenario::take_shared<ResultRegistry>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            
            // Add result
            result_registry::add_result(
                &institution_cap,
                &mut registry,
                string::utf8(b"STU001"),
                string::utf8(b"CS101"),
                string::utf8(b"A"),
                string::utf8(b"Fall2024"),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            // Verify result
            result_registry::verify_result(
                &institution_cap,
                &mut registry,
                string::utf8(b"STU001"),
                string::utf8(b"CS101"),
                string::utf8(b"Fall2024"),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            // Check if result is verified
            assert!(result_registry::is_result_verified(
                &registry,
                string::utf8(b"STU001"),
                string::utf8(b"CS101"),
                string::utf8(b"Fall2024")
            ), 0);
            
            test_scenario::return_to_sender(&scenario, institution_cap);
            test_scenario::return_shared(registry);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2)] // E_INVALID_GRADE
    fun test_invalid_grade_fails() {
        let mut scenario = init_test_scenario();
        
        {
            result_registry::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, ADMIN);
        
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut registry = test_scenario::take_shared<ResultRegistry>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            
            result_registry::authorize_institution(
                &admin_cap,
                &mut registry,
                INSTITUTION1,
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_to_sender(&scenario, admin_cap);
            test_scenario::return_shared(registry);
            clock::destroy_for_testing(clock);
        };

        test_scenario::next_tx(&mut scenario, INSTITUTION1);
        
        {
            let institution_cap = test_scenario::take_from_sender<InstitutionCap>(&scenario);
            let mut registry = test_scenario::take_shared<ResultRegistry>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            
            // Try to add result with invalid grade - should fail
            result_registry::add_result(
                &institution_cap,
                &mut registry,
                string::utf8(b"STU001"),
                string::utf8(b"CS101"),
                string::utf8(b"X"), // Invalid grade
                string::utf8(b"Fall2024"),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_to_sender(&scenario, institution_cap);
            test_scenario::return_shared(registry);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 3)] // E_RESULT_ALREADY_EXISTS
    fun test_duplicate_result_fails() {
        let mut scenario = init_test_scenario();
        
        {
            result_registry::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, ADMIN);
        
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut registry = test_scenario::take_shared<ResultRegistry>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            
            result_registry::authorize_institution(
                &admin_cap,
                &mut registry,
                INSTITUTION1,
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_to_sender(&scenario, admin_cap);
            test_scenario::return_shared(registry);
            clock::destroy_for_testing(clock);
        };

        test_scenario::next_tx(&mut scenario, INSTITUTION1);
        
        {
            let institution_cap = test_scenario::take_from_sender<InstitutionCap>(&scenario);
            let mut registry = test_scenario::take_shared<ResultRegistry>(&scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            
            // Add first result
            result_registry::add_result(
                &institution_cap,
                &mut registry,
                string::utf8(b"STU001"),
                string::utf8(b"CS101"),
                string::utf8(b"A"),
                string::utf8(b"Fall2024"),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            // Try to add same result again - should fail
            result_registry::add_result(
                &institution_cap,
                &mut registry,
                string::utf8(b"STU001"),
                string::utf8(b"CS101"),
                string::utf8(b"B"),
                string::utf8(b"Fall2024"),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_to_sender(&scenario, institution_cap);
            test_scenario::return_shared(registry);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }
}
