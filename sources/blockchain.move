/// Module: blockchain
/// A decentralized result management system on SUI blockchain
/// Provides tamper-proof storage and verification of academic results
module blockchain::result_registry_v2 {
    use sui::object;
    use sui::tx_context;
    use std::string::{Self, String};
    use sui::table::{Self, Table};
    use sui::event;
    use sui::clock::{Self, Clock};

    // Error codes
    const E_RESULT_NOT_FOUND: u64 = 0;
    const E_INVALID_GRADE: u64 = 2;
    const E_RESULT_ALREADY_EXISTS: u64 = 3;

    // Valid grades
    const GRADE_A: vector<u8> = b"A";
    const GRADE_B: vector<u8> = b"B";
    const GRADE_C: vector<u8> = b"C";
    const GRADE_D: vector<u8> = b"D";
    const GRADE_E: vector<u8> = b"E";
    const GRADE_F: vector<u8> = b"F";

    /// Represents a student's result for a specific course
    public struct Result has key, store {
        id: UID,
        student_id: String,
        course_code: String,
        grade: String,
        semester: String,
        recorded_by: address,
        created_at: u64,
        updated_at: u64,
        verified: bool,
    }

    /// Registry to store all results
    public struct ResultRegistry has key {
        id: UID,
        results: Table<String, Result>,
        admin: address,
        authorized_institutions: Table<address, bool>,
    }

    /// Admin capability for managing the registry
    public struct AdminCap has key {
        id: UID,
    }

    /// Institution capability for adding/updating results
    public struct InstitutionCap has key {
        id: UID,
        institution_address: address,
    }

    // Events
    public struct ResultAdded has copy, drop {
        student_id: String,
        course_code: String,
        grade: String,
        semester: String,
        recorded_by: address,
        timestamp: u64,
    }

    public struct ResultUpdated has copy, drop {
        student_id: String,
        course_code: String,
        old_grade: String,
        new_grade: String,
        semester: String,
        updated_by: address,
        timestamp: u64,
    }

    public struct ResultVerified has copy, drop {
        student_id: String,
        course_code: String,
        semester: String,
        verified_by: address,
        timestamp: u64,
    }

    public struct InstitutionAuthorized has copy, drop {
        institution_address: address,
        authorized_by: address,
        timestamp: u64,
    }

    /// Initialize the result registry (called once during deployment)
    fun init(ctx: &mut TxContext) {
        let admin = tx_context::sender(ctx);
        
        let registry = ResultRegistry {
            id: object::new(ctx),
            results: table::new(ctx),
            admin,
            authorized_institutions: table::new(ctx),
        };

        let admin_cap = AdminCap {
            id: object::new(ctx),
        };

        transfer::share_object(registry);
        transfer::transfer(admin_cap, admin);
    }

    /// Generate a unique key for a result
    fun generate_result_key(student_id: &String, course_code: &String, semester: &String): String {
        let mut key = string::utf8(b"");
        string::append(&mut key, *student_id);
        string::append_utf8(&mut key, b"_");
        string::append(&mut key, *course_code);
        string::append_utf8(&mut key, b"_");
        string::append(&mut key, *semester);
        key
    }

    /// Validate if a grade is acceptable
    fun is_valid_grade(grade: &String): bool {
        let grade_bytes = string::as_bytes(grade);
        *grade_bytes == GRADE_A ||
        *grade_bytes == GRADE_B ||
        *grade_bytes == GRADE_C ||
        *grade_bytes == GRADE_D ||
        *grade_bytes == GRADE_E ||
        *grade_bytes == GRADE_F
    }

    /// Authorize an institution to add/update results
    public fun authorize_institution(
        _: &AdminCap,
        registry: &mut ResultRegistry,
        institution_address: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        table::add(&mut registry.authorized_institutions, institution_address, true);
        
        let institution_cap = InstitutionCap {
            id: object::new(ctx),
            institution_address,
        };

        event::emit(InstitutionAuthorized {
            institution_address,
            authorized_by: tx_context::sender(ctx),
            timestamp: clock::timestamp_ms(clock),
        });

        transfer::transfer(institution_cap, institution_address);
    }

    /// Add a new result to the registry
    public fun add_result(
        _: &InstitutionCap,
        registry: &mut ResultRegistry,
        student_id: String,
        course_code: String,
        grade: String,
        semester: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate grade
        assert!(is_valid_grade(&grade), E_INVALID_GRADE);

        let key = generate_result_key(&student_id, &course_code, &semester);
        
        // Check if result already exists
        assert!(!table::contains(&registry.results, key), E_RESULT_ALREADY_EXISTS);

        let timestamp = clock::timestamp_ms(clock);
        let recorded_by = tx_context::sender(ctx);

        let result = Result {
            id: object::new(ctx),
            student_id: student_id,
            course_code: course_code,
            grade: grade,
            semester: semester,
            recorded_by,
            created_at: timestamp,
            updated_at: timestamp,
            verified: false,
        };

        // Emit event
        event::emit(ResultAdded {
            student_id: result.student_id,
            course_code: result.course_code,
            grade: result.grade,
            semester: result.semester,
            recorded_by,
            timestamp,
        });

        table::add(&mut registry.results, key, result);
    }

    /// Update an existing result's grade
    public fun update_grade(
        _: &InstitutionCap,
        registry: &mut ResultRegistry,
        student_id: String,
        course_code: String,
        semester: String,
        new_grade: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate new grade
        assert!(is_valid_grade(&new_grade), E_INVALID_GRADE);

        let key = generate_result_key(&student_id, &course_code, &semester);
        
        // Check if result exists
        assert!(table::contains(&registry.results, key), E_RESULT_NOT_FOUND);

        let result = table::borrow_mut(&mut registry.results, key);
        let old_grade = result.grade;
        
        result.grade = new_grade;
        result.updated_at = clock::timestamp_ms(clock);
        result.verified = false; // Reset verification status on update

        // Emit event
        event::emit(ResultUpdated {
            student_id,
            course_code,
            old_grade,
            new_grade: result.grade,
            semester,
            updated_by: tx_context::sender(ctx),
            timestamp: result.updated_at,
        });
    }

    /// Verify a result (mark as verified by an authorized institution)
    public fun verify_result(
        _: &InstitutionCap,
        registry: &mut ResultRegistry,
        student_id: String,
        course_code: String,
        semester: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let key = generate_result_key(&student_id, &course_code, &semester);
        
        // Check if result exists
        assert!(table::contains(&registry.results, key), E_RESULT_NOT_FOUND);

        let result = table::borrow_mut(&mut registry.results, key);
        result.verified = true;

        let timestamp = clock::timestamp_ms(clock);

        // Emit event
        event::emit(ResultVerified {
            student_id,
            course_code,
            semester,
            verified_by: tx_context::sender(ctx),
            timestamp,
        });
    }

    /// Get a result (read-only function)
    public fun get_result(
        registry: &ResultRegistry,
        student_id: String,
        course_code: String,
        semester: String
    ): (String, String, String, String, address, u64, u64, bool) {
        let key = generate_result_key(&student_id, &course_code, &semester);
        
        // Check if result exists
        assert!(table::contains(&registry.results, key), E_RESULT_NOT_FOUND);

        let result = table::borrow(&registry.results, key);
        (
            result.student_id,
            result.course_code,
            result.grade,
            result.semester,
            result.recorded_by,
            result.created_at,
            result.updated_at,
            result.verified
        )
    }

    /// Check if a result exists
    public fun result_exists(
        registry: &ResultRegistry,
        student_id: String,
        course_code: String,
        semester: String
    ): bool {
        let key = generate_result_key(&student_id, &course_code, &semester);
        table::contains(&registry.results, key)
    }

    /// Get result verification status
    public fun is_result_verified(
        registry: &ResultRegistry,
        student_id: String,
        course_code: String,
        semester: String
    ): bool {
        let key = generate_result_key(&student_id, &course_code, &semester);
        
        if (!table::contains(&registry.results, key)) {
            return false
        };

        let result = table::borrow(&registry.results, key);
        result.verified
    }

    /// Check if an institution is authorized
    public fun is_institution_authorized(
        registry: &ResultRegistry,
        institution_address: address
    ): bool {
        table::contains(&registry.authorized_institutions, institution_address)
    }

    // Getter functions for Result struct
    public fun get_result_student_id(result: &Result): &String {
        &result.student_id
    }

    public fun get_result_course_code(result: &Result): &String {
        &result.course_code
    }

    public fun get_result_grade(result: &Result): &String {
        &result.grade
    }

    public fun get_result_semester(result: &Result): &String {
        &result.semester
    }

    public fun get_result_recorded_by(result: &Result): address {
        result.recorded_by
    }

    public fun get_result_created_at(result: &Result): u64 {
        result.created_at
    }

    public fun get_result_updated_at(result: &Result): u64 {
        result.updated_at
    }

    public fun get_result_verified(result: &Result): bool {
        result.verified
    }

    #[test_only]
    /// Test-only function to initialize the module for testing
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    // Entry functions for transaction calls
    entry fun authorize_institution_entry(
        admin_cap: &AdminCap,
        registry: &mut ResultRegistry,
        institution_address: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        authorize_institution(admin_cap, registry, institution_address, clock, ctx);
    }

    entry fun add_result_entry(
        institution_cap: &InstitutionCap,
        registry: &mut ResultRegistry,
        student_id: String,
        course_code: String,
        grade: String,
        semester: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        add_result(institution_cap, registry, student_id, course_code, grade, semester, clock, ctx);
    }

    entry fun update_grade_entry(
        institution_cap: &InstitutionCap,
        registry: &mut ResultRegistry,
        student_id: String,
        course_code: String,
        semester: String,
        new_grade: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        update_grade(institution_cap, registry, student_id, course_code, semester, new_grade, clock, ctx);
    }

    entry fun verify_result_entry(
        institution_cap: &InstitutionCap,
        registry: &mut ResultRegistry,
        student_id: String,
        course_code: String,
        semester: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        verify_result(institution_cap, registry, student_id, course_code, semester, clock, ctx);
    }
}