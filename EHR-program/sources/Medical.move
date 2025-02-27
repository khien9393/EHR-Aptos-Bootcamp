module Agent {
    use 0x1::Signer;
    use 0x1::Event;
    use 0x1::Vector;

    resource struct Patient {
        name: vector<u8>,
        age: u64,
        doctor_access_list: vector<address>,
        diagnosis: vector<u64>,
        record: vector<u8>,
    }

    resource struct Doctor {
        name: vector<u8>,
        age: u64,
        patient_access_list: vector<address>,
    }

    resource struct AgentData {
        credit_pool: u64,
        patient_list: vector<address>,
        doctor_list: vector<address>,
        patient_info: table::Table<address, Patient>,
        doctor_info: table::Table<address, Doctor>,
    }

    public fun initialize(owner: &signer) {
        let agent_data = AgentData {
            credit_pool: 0,
            patient_list: Vector::empty(),
            doctor_list: Vector::empty(),
            patient_info: table::Table::new<address, Patient>(),
            doctor_info: table::Table::new<address, Doctor>(),
        };
        move_to(owner, agent_data);
    }

    public fun add_agent(owner: &signer, name: vector<u8>, age: u64, designation: u8, record: vector<u8>) {
        let addr = Signer::address_of(owner);
        let agent_data = borrow_global_mut<AgentData>(addr);

        if (designation == 0) {
            let patient = Patient {
                name,
                age,
                doctor_access_list: Vector::empty(),
                diagnosis: Vector::empty(),
                record,
            };
            table::Table::add(&mut agent_data.patient_info, addr, patient);
            Vector::push_back(&mut agent_data.patient_list, addr);
        } else if (designation == 1) {
            let doctor = Doctor {
                name,
                age,
                patient_access_list: Vector::empty(),
            };
            table::Table::add(&mut agent_data.doctor_info, addr, doctor);
            Vector::push_back(&mut agent_data.doctor_list, addr);
        } else {
            abort(1); // Invalid designation
        }
    }

    public fun get_patient(owner: &signer, addr: address): (vector<u8>, u64, vector<u64>, vector<u8>) {
        let agent_data = borrow_global<AgentData>(Signer::address_of(owner));
        let patient = table::Table::borrow(&agent_data.patient_info, addr);
        (patient.name, patient.age, patient.diagnosis, patient.record)
    }

    public fun get_doctor(owner: &signer, addr: address): (vector<u8>, u64) {
        let agent_data = borrow_global<AgentData>(Signer::address_of(owner));
        let doctor = table::Table::borrow(&agent_data.doctor_info, addr);
        (doctor.name, doctor.age)
    }

    public fun permit_access(owner: &signer, addr: address) {
        let agent_data = borrow_global_mut<AgentData>(Signer::address_of(owner));
        agent_data.credit_pool += 2;

        let doctor = table::Table::borrow_mut(&mut agent_data.doctor_info, addr);
        Vector::push_back(&mut doctor.patient_access_list, Signer::address_of(owner));

        let patient = table::Table::borrow_mut(&mut agent_data.patient_info, Signer::address_of(owner));
        Vector::push_back(&mut patient.doctor_access_list, addr);
    }

    public fun insurance_claim(owner: &signer, paddr: address, diagnosis: u64, record: vector<u8>) {
        let agent_data = borrow_global_mut<AgentData>(Signer::address_of(owner));
        let doctor = table::Table::borrow_mut(&mut agent_data.doctor_info, Signer::address_of(owner));

        let mut patient_found = false;
        for patient_addr in &doctor.patient_access_list {
            if (*patient_addr == paddr) {
                patient_found = true;
                break;
            }
        }

        if (!patient_found) {
            abort(1); // Patient not found
        }

        let patient = table::Table::borrow_mut(&mut agent_data.patient_info, paddr);
        let mut diagnosis_found = false;
        for diag in &patient.diagnosis {
            if (*diag == diagnosis) {
                diagnosis_found = true;
                break;
            }
        }

        if (!diagnosis_found) {
            abort(2); // Diagnosis not found
        }

        patient.record = record;
        agent_data.credit_pool -= 2;
        Vector::remove(&mut doctor.patient_access_list, paddr);
        Vector::remove(&mut patient.doctor_access_list, Signer::address_of(owner));
    }

    public fun get_accessed_doctorlist_for_patient(owner: &signer, addr: address): vector<address> {
        let agent_data = borrow_global<AgentData>(Signer::address_of(owner));
        let patient = table::Table::borrow(&agent_data.patient_info, addr);
        patient.doctor_access_list
    }

    public fun get_accessed_patientlist_for_doctor(owner: &signer, addr: address): vector<address> {
        let agent_data = borrow_global<AgentData>(Signer::address_of(owner));
        let doctor = table::Table::borrow(&agent_data.doctor_info, addr);
        doctor.patient_access_list
    }

    public fun revoke_access(owner: &signer, daddr: address) {
        let agent_data = borrow_global_mut<AgentData>(Signer::address_of(owner));
        let patient = table::Table::borrow_mut(&mut agent_data.patient_info, Signer::address_of(owner));
        let doctor = table::Table::borrow_mut(&mut agent_data.doctor_info, daddr);

        Vector::remove(&mut doctor.patient_access_list, Signer::address_of(owner));
        Vector::remove(&mut patient.doctor_access_list, daddr);

        agent_data.credit_pool -= 2;
    }

    public fun get_patient_list(owner: &signer): vector<address> {
        let agent_data = borrow_global<AgentData>(Signer::address_of(owner));
        agent_data.patient_list
    }

    public fun get_doctor_list(owner: &signer): vector<address> {
        let agent_data = borrow_global<AgentData>(Signer::address_of(owner));
        agent_data.doctor_list
    }

    public fun get_hash(owner: &signer, paddr: address): vector<u8> {
        let agent_data = borrow_global<AgentData>(Signer::address_of(owner));
        let patient = table::Table::borrow(&agent_data.patient_info, paddr);
        patient.record
    }

    public fun set_hash(owner: &signer, paddr: address, record: vector<u8>) {
        let agent_data = borrow_global_mut<AgentData>(Signer::address_of(owner));
        let patient = table::Table::borrow_mut(&mut agent_data.patient_info, paddr);
        patient.record = record;
    }
}
